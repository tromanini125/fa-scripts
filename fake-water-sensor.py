#!/usr/bin/env python3
"""
Farm Automation - Simulador de Sensor de Fluxo de Agua
=======================================================
Conecta direto no IP publico do cluster (sem port-forward).
Dependencia:  pip install paho-mqtt
Uso rapido:
  python3 fake-water-sensor.py --simulate              # ciclo: nivel 100%->70%(bomba ON)->100%
  python3 fake-water-sensor.py --simulate --cycles 5 --step-time 1
  python3 fake-water-sensor.py --auto                  # 3 ciclos ON/OFF automaticos
  python3 fake-water-sensor.py --on                    # liga bomba uma vez
  python3 fake-water-sensor.py --off                   # desliga bomba uma vez
  python3 fake-water-sensor.py                         # menu interativo
"""
import argparse
import json
import random
import signal
import sys
import time
from datetime import datetime, timezone, timedelta
try:
    import paho.mqtt.client as mqtt
except ImportError:
    print("Biblioteca paho-mqtt nao encontrada. Instale com: pip install paho-mqtt")
    sys.exit(1)
# ── Configuracao do broker (mesmo que o Arduino usa) ──────────────────────────
MQTT_HOST          = "163.176.163.180"   # IP publico do cluster
MQTT_PORT          = 1883
MQTT_USER          = "ard_wfs"
MQTT_PASS          = "chItD9ZTWYSHqmrr"
MQTT_CLIENT_ID          = "fa-fake-sensor-01"
MQTT_TOPIC              = "water-flux"          # mesmo topico do Arduino (#define WATER_FLUX_TOPIC)
MQTT_WATER_LEVEL_TOPIC  = "water-level"         # mesmo topico do Arduino (#define WATER_LEVEL_TOPIC)
PUMP_ON_THRESHOLD       = 0.5                   # flowRate > 0.5 L/min = bomba ligada
# ── Cores terminal ────────────────────────────────────────────────────────────
GREEN  = "\033[92m"; RED  = "\033[91m"; YELLOW = "\033[93m"
CYAN   = "\033[96m"; BOLD = "\033[1m";  RESET  = "\033[0m"
BRT = timezone(timedelta(hours=-3))

def log(msg):
    print(f"[{datetime.now(BRT).strftime('%H:%M:%S')}] {msg}")
# ── MQTT ──────────────────────────────────────────────────────────────────────
def create_client() -> mqtt.Client:
    client = mqtt.Client(client_id=MQTT_CLIENT_ID, protocol=mqtt.MQTTv311)
    client.username_pw_set(MQTT_USER, MQTT_PASS)
    def on_connect(c, userdata, flags, rc):
        codes = {
            0: f"{GREEN}OK - Conectado{RESET}",
            1: "Protocolo recusado",
            2: "Client ID rejeitado",
            3: "Broker indisponivel",
            4: "Credenciais invalidas",
            5: "Nao autorizado",
        }
        log(f"MQTT: {codes.get(rc, f'rc={rc}')}")
    client.on_connect = on_connect
    return client
def connect_client(client: mqtt.Client, host: str, port: int) -> bool:
    try:
        client.connect(host, port, keepalive=60)
        client.loop_start()
        time.sleep(1.5)
        return client.is_connected()
    except Exception as e:
        log(f"Erro ao conectar: {e}")
        return False
# ── Publicacao ────────────────────────────────────────────────────────────────
def publish(client: mqtt.Client, flow_rate: float, water_level_pct: float = None):
    """
    Publica flowRate no topico water-flux.
    Se water_level_pct for informado (0-100%), converte para escala 0-10
    e publica tambem no topico water-level (mesmo formato do Arduino).
    """
    ts = int(time.time())

    # ── water-flux ────────────────────────────────────────────────────────────
    flux_payload = {"timestamp": ts, "flowRate": round(flow_rate, 2)}
    result = client.publish(MQTT_TOPIC, json.dumps(flux_payload), qos=1)
    result.wait_for_publish(timeout=5)

    # ── water-level ───────────────────────────────────────────────────────────
    if water_level_pct is not None:
        level_int = round(water_level_pct / 10)          # 100% -> 10, 70% -> 7
        level_payload = {"timestamp": ts, "level": level_int}
        r2 = client.publish(MQTT_WATER_LEVEL_TOPIC, json.dumps(level_payload), qos=1)
        r2.wait_for_publish(timeout=5)

    # ── log ───────────────────────────────────────────────────────────────────
    estado = f"{GREEN}LIGADA  [ON]{RESET}" if flow_rate > PUMP_ON_THRESHOLD else f"{RED}DESLIGADA [OFF]{RESET}"
    level_str = f" | Nivel: {water_level_pct:.1f}% (level={round(water_level_pct/10)})" if water_level_pct is not None else ""
    log(f"Publicado -> water-flux flowRate={flow_rate:.2f} L/min | Bomba: {estado}{level_str}")
    return flux_payload
def cmd_on(client):
    publish(client, round(random.uniform(1.5, 3.5), 2))
def cmd_off(client):
    publish(client, 0.0)
# ── Simulacao de nivel de agua ────────────────────────────────────────────────
def mode_simulate(client, cycles: int, step_time: float):
    """
    Simula ciclo completo:
      - Nivel inicia em 100%
      - Cai 5% a cada step_time segundos
      - Ao atingir 70%: liga bomba (flowRate 3.xx - 4.xx)
      - Com bomba ON: sobe 5% a cada step_time segundos
      - Ao atingir 100%: desliga bomba -> repete
    """
    PUMP_ON_LEVEL  = 70.0
    PUMP_OFF_LEVEL = 100.0
    STEP           = 5.0

    log(f"{BOLD}Modo simulacao: {cycles} ciclo(s) | passo=5% a cada {step_time}s{RESET}")
    log(f"  Bomba LIGA em {PUMP_ON_LEVEL}% | Bomba DESLIGA em {PUMP_OFF_LEVEL}%")

    for cycle in range(1, cycles + 1):
        log(f"{CYAN}==== Ciclo {cycle}/{cycles} ===={RESET}")
        level = PUMP_OFF_LEVEL
        pump_on = False

        # Fase 1: nivel caindo de 100 ate 70
        log(f"{YELLOW}Fase 1: nivel descendo...{RESET}")
        while level > PUMP_ON_LEVEL:
            publish(client, 0.0, level)
            time.sleep(step_time)
            level = round(level - STEP, 1)

        # Nivel chegou em 70% -> liga bomba
        pump_on = True
        log(f"{GREEN}Nivel em {PUMP_ON_LEVEL}% -> Ligando bomba!{RESET}")

        # Fase 2: nivel subindo de 70 ate 100
        log(f"{YELLOW}Fase 2: nivel subindo com bomba ligada...{RESET}")
        while level <= PUMP_OFF_LEVEL:
            flow = round(random.uniform(3.0, 4.99), 2)
            publish(client, flow, level)
            if level >= PUMP_OFF_LEVEL:
                break
            time.sleep(step_time)
            level = round(level + STEP, 1)

        # Nivel voltou a 100% -> desliga bomba
        log(f"{RED}Nivel em {PUMP_OFF_LEVEL}% -> Desligando bomba!{RESET}")
        publish(client, 0.0, PUMP_OFF_LEVEL)

        if cycle < cycles:
            time.sleep(step_time)

    log(f"{GREEN}Simulacao concluida.{RESET}")
# ── Modos ─────────────────────────────────────────────────────────────────────
def mode_auto(client, cycles: int, on_seconds: float, off_seconds: float):
    log(f"{BOLD}Modo automatico: {cycles} ciclo(s) | LIGADA={on_seconds}s / DESLIGADA={off_seconds}s{RESET}")
    for i in range(cycles):
        log(f"{CYAN}---- Ciclo {i+1}/{cycles} ----{RESET}")
        publish(client, round(random.uniform(1.5, 3.5), 2))
        log(f"   Aguardando {on_seconds}s...")
        time.sleep(on_seconds)
        publish(client, 0.0)
        if i < cycles - 1:
            log(f"   Aguardando {off_seconds}s...")
            time.sleep(off_seconds)
    log(f"{GREEN}Ciclos concluidos.{RESET}")
def mode_interactive(client, host, port):
    print(f"""
{BOLD}{CYAN}==== Farm Automation - Simulador de Bomba d'Agua ===={RESET}
  Broker : {host}:{port}
  Topico : {MQTT_TOPIC}
  {GREEN}[1]{RESET} Ligar bomba     (flowRate ~2.5 L/min)
  {RED}[2]{RESET} Desligar bomba  (flowRate = 0)
  {YELLOW}[3]{RESET} Ciclo automatico (ON -> OFF -> ...)
  {CYAN}[4]{RESET} Leituras continuas aleatorias
  {CYAN}[5]{RESET} Simulacao de nivel de agua (100% -> 70% -> 100%)
  {BOLD}[0]{RESET} Sair
""")
    while True:
        try:
            choice = input(f"{BOLD}Opcao > {RESET}").strip()
        except (EOFError, KeyboardInterrupt):
            break
        if choice == "1":
            cmd_on(client)
        elif choice == "2":
            cmd_off(client)
        elif choice == "3":
            try:
                n    = int(input("  Ciclos? [2]: ") or "2")
                on_t = float(input("  Seg. ligada? [3]: ") or "3")
                off_t= float(input("  Seg. desligada? [3]: ") or "3")
            except ValueError:
                n, on_t, off_t = 2, 3.0, 3.0
            mode_auto(client, n, on_t, off_t)
        elif choice == "4":
            try:
                total    = int(input("  Leituras? [10]: ") or "10")
                interval = float(input("  Intervalo (s)? [2]: ") or "2")
                pct_on   = float(input("  % ligada? [60]: ") or "60") / 100
            except ValueError:
                total, interval, pct_on = 10, 2.0, 0.6
            log(f"Enviando {total} leituras...")
            for i in range(total):
                flow = round(random.uniform(1.0, 3.5), 2) if random.random() < pct_on else 0.0
                publish(client, flow)
                if i < total - 1:
                    time.sleep(interval)
        elif choice == "5":
            try:
                n      = int(input("  Ciclos? [1]: ") or "1")
                step_t = float(input("  Intervalo por passo 5% (s)? [2]: ") or "2")
            except ValueError:
                n, step_t = 1, 2.0
            mode_simulate(client, n, step_t)
        elif choice == "0":
            break
        else:
            print(f"  {YELLOW}Opcao invalida.{RESET}")
        print()
# ── Graceful shutdown ─────────────────────────────────────────────────────────
def handle_signal(sig, frame):
    log("Interrompido.")
    sys.exit(0)
signal.signal(signal.SIGINT,  handle_signal)
signal.signal(signal.SIGTERM, handle_signal)
# ── Main ──────────────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(description="Simulador de sensor de agua - Farm Automation")
    parser.add_argument("--host",     default=MQTT_HOST, help=f"Broker MQTT (padrao: {MQTT_HOST})")
    parser.add_argument("--port",     default=MQTT_PORT, type=int, help=f"Porta MQTT (padrao: {MQTT_PORT})")
    parser.add_argument("--auto",     action="store_true", help="Ciclos automaticos ON/OFF")
    parser.add_argument("--cycles",   default=3,   type=int,   help="Numero de ciclos no --auto ou --simulate (padrao: 3)")
    parser.add_argument("--on-time",  default=3.0, type=float, help="Segundos ligada por ciclo (padrao: 3)")
    parser.add_argument("--off-time", default=3.0, type=float, help="Segundos desligada por ciclo (padrao: 3)")
    parser.add_argument("--on",       action="store_true", help="Envia UMA leitura: bomba LIGADA")
    parser.add_argument("--off",      action="store_true", help="Envia UMA leitura: bomba DESLIGADA")
    parser.add_argument("--simulate", action="store_true", help="Simula ciclo de nivel de agua: 100%->70%(bomba ON)->100%")
    parser.add_argument("--step-time",default=2.0, type=float, help="Segundos entre cada passo de 5%% no --simulate (padrao: 2)")
    args = parser.parse_args()
    client = create_client()
    log(f"Conectando em {args.host}:{args.port} como '{MQTT_USER}'...")
    if not connect_client(client, args.host, args.port):
        log("Falha na conexao. Verifique host, porta e credenciais.")
        sys.exit(1)
    try:
        if args.on:
            cmd_on(client)
        elif args.off:
            cmd_off(client)
        elif args.auto:
            mode_auto(client, args.cycles, args.on_time, args.off_time)
        elif args.simulate:
            mode_simulate(client, args.cycles, args.step_time)
        else:
            mode_interactive(client, args.host, args.port)
    finally:
        client.loop_stop()
        client.disconnect()
    log("Encerrado.")
if __name__ == "__main__":
    main()
