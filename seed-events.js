#!/usr/bin/env node

// Script para popular eventos aleatórios na agenda
const http = require('http');
const https = require('https');

const API_URL = 'http://localhost:3000';
let authToken = '';

// Tipos de eventos agrícolas
const eventTypes = [
  { title: 'Irrigação do cafezal', description: 'Irrigação programada da área de café', color: '#3788d8' },
  { title: 'Aplicação de fertilizante', description: 'Aplicação de NPK nas áreas de cultivo', color: '#28a745' },
  { title: 'Controle de pragas', description: 'Aplicação de defensivos agrícolas', color: '#dc3545' },
  { title: 'Colheita de hortaliças', description: 'Colheita programada das hortaliças', color: '#ffc107' },
  { title: 'Manutenção de equipamentos', description: 'Revisão e manutenção de tratores e implementos', color: '#6c757d' },
  { title: 'Plantio de mudas', description: 'Plantio de novas mudas na área preparada', color: '#20c997' },
  { title: 'Poda de árvores frutíferas', description: 'Poda de formação e limpeza', color: '#fd7e14' },
  { title: 'Adubação verde', description: 'Plantio de culturas para adubação verde', color: '#198754' },
  { title: 'Análise de solo', description: 'Coleta de amostras para análise laboratorial', color: '#6f42c1' },
  { title: 'Vacinação do gado', description: 'Vacinação programada do rebanho', color: '#d63384' },
  { title: 'Limpeza de açudes', description: 'Manutenção e limpeza dos reservatórios de água', color: '#0dcaf0' },
  { title: 'Monitoramento de culturas', description: 'Inspeção e monitoramento das áreas cultivadas', color: '#198754' },
  { title: 'Aplicação de calcário', description: 'Correção de acidez do solo', color: '#adb5bd' },
  { title: 'Treinamento equipe', description: 'Capacitação da equipe de campo', color: '#6610f2' },
  { title: 'Reunião planejamento', description: 'Reunião de planejamento agrícola', color: '#0d6efd' }
];

// Função para fazer requisição HTTP
function makeRequest(method, path, data = null, headers = {}) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, API_URL);
    const options = {
      hostname: url.hostname,
      port: url.port,
      path: url.pathname,
      method: method,
      headers: {
        'Content-Type': 'application/json',
        ...headers
      }
    };

    const req = http.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
        try {
          const response = JSON.parse(body);
          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve(response);
          } else {
            reject(new Error(`HTTP ${res.statusCode}: ${JSON.stringify(response)}`));
          }
        } catch (e) {
          reject(new Error(`Parse error: ${body}`));
        }
      });
    });

    req.on('error', reject);
    if (data) req.write(JSON.stringify(data));
    req.end();
  });
}

// Função para gerar data aleatória nos próximos 4 meses
function getRandomDate() {
  const today = new Date(2026, 1, 4); // 4 de fevereiro de 2026
  const daysAhead = Math.floor(Math.random() * 120); // 0-120 dias à frente
  const date = new Date(today);
  date.setDate(date.getDate() + daysAhead);
  return date;
}

// Função para formatar data como YYYY-MM-DD
function formatDate(date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

// Função para formatar data e hora como RFC3339 com timezone brasileiro
function formatDateTime(date, time) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}T${time}:00-03:00`;
}

// Função para gerar horário aleatório
function getRandomTime() {
  const hour = Math.floor(Math.random() * 13) + 6; // 6h às 18h
  const minute = Math.random() < 0.5 ? '00' : '30';
  return `${String(hour).padStart(2, '0')}:${minute}`;
}

// Função para fazer login
async function login() {
  try {
    const response = await makeRequest('POST', '/api/auth/login', {
      email: 'tromanini125@gmail.com',
      password: '12345678'
    });
    authToken = response.accessToken;
    console.log('✅ Login realizado com sucesso');
    return true;
  } catch (error) {
    console.error('❌ Erro ao fazer login:', error.message);
    return false;
  }
}

// Função para criar evento
async function createEvent(eventData) {
  try {
    await makeRequest('POST', '/api/events', eventData, {
      'Authorization': `Bearer ${authToken}`
    });
    return true;
  } catch (error) {
    console.error('❌ Erro ao criar evento:', error.message);
    return false;
  }
}

// Função principal
async function seedEvents() {
  console.log('🌱 Iniciando seed de eventos...\n');

  const loggedIn = await login();
  if (!loggedIn) {
    console.log('❌ Não foi possível fazer login. Encerrando...');
    return;
  }

  const numEvents = 35 + Math.floor(Math.random() * 15);
  console.log(`📅 Criando ${numEvents} eventos...\n`);

  let created = 0;

  for (let i = 0; i < numEvents; i++) {
    const eventType = eventTypes[Math.floor(Math.random() * eventTypes.length)];
    const date = getRandomDate();
    const startTime = getRandomTime();
    
    const duration = 1 + Math.floor(Math.random() * 3);
    const startHour = parseInt(startTime.split(':')[0]);
    const endHour = startHour + duration;
    const endTime = `${String(endHour).padStart(2, '0')}:${startTime.split(':')[1]}`;

    const allDay = Math.random() < 0.15;

    const event = {
      title: eventType.title,
      description: eventType.description,
      start_date: allDay ? formatDateTime(date, '00:00') : formatDateTime(date, startTime),
      end_date: allDay ? formatDateTime(date, '23:59') : formatDateTime(date, endTime),
      color: eventType.color,
      all_day: allDay,
      permissions: {
        public: Math.random() < 0.7,
        viewable_by: [],
        editable_by: []
      }
    };

    const success = await createEvent(event);
    if (success) {
      created++;
      console.log(`✅ ${created}/${numEvents} - ${event.title} em ${formatDate(date)}`);
    }

    await new Promise(resolve => setTimeout(resolve, 50));
  }

  console.log('\n📊 Resultado:');
  console.log(`   ✅ Criados: ${created}/${numEvents}`);
  console.log('\n🎉 Seed de eventos concluído!');
}

seedEvents().catch(console.error);
