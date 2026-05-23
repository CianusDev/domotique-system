import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../generated/prisma/client';
import 'dotenv/config';

const adapter = new PrismaPg({ connectionString: process.env['DATABASE_URL']! });
const prisma = new PrismaClient({ adapter });

const sensorTypes = [
  {
    type: 'DHT22',
    name: 'DHT22 — Temperature & Humidity',
    description: 'Digital sensor. Temperature −40…+80°C (±0.5°C), Humidity 0–100% RH (±2–5%).',
    category: 'climate',
    dataFields: [
      { field: 'temperature', unit: '°C',  dataType: 'float' },
      { field: 'humidity',    unit: '%RH', dataType: 'float' },
    ],
  },
  {
    type: 'DHT11',
    name: 'DHT11 — Temperature & Humidity',
    description: 'Budget digital sensor. Temperature 0–50°C (±2°C), Humidity 20–80% RH (±5%).',
    category: 'climate',
    dataFields: [
      { field: 'temperature', unit: '°C',  dataType: 'float' },
      { field: 'humidity',    unit: '%RH', dataType: 'float' },
    ],
  },
  {
    type: 'PIR',
    name: 'PIR — Passive Infrared Motion',
    description: 'HC-SR501 or equivalent. Detects motion via infrared. Digital output.',
    category: 'motion',
    dataFields: [
      { field: 'motion', unit: 'bool', dataType: 'boolean' },
    ],
  },
  {
    type: 'DS18B20',
    name: 'DS18B20 — Waterproof Temperature',
    description: '1-Wire digital thermometer. Range −55…+125°C (±0.5°C). Multiple sensors per pin.',
    category: 'temperature',
    dataFields: [
      { field: 'temperature', unit: '°C', dataType: 'float' },
    ],
  },
  {
    type: 'LDR',
    name: 'LDR — Light Dependent Resistor',
    description: 'Analog light level sensor via voltage divider. Raw ADC value (0–4095 on ESP32).',
    category: 'light',
    dataFields: [
      { field: 'light', unit: 'lux', dataType: 'float' },
      { field: 'raw',   unit: 'adc', dataType: 'integer' },
    ],
  },
  {
    type: 'HC_SR04',
    name: 'HC-SR04 — Ultrasonic Distance',
    description: 'Ultrasonic range sensor. Distance 2–400 cm (±3 mm). Requires trigger + echo pins.',
    category: 'distance',
    dataFields: [
      { field: 'distance', unit: 'cm', dataType: 'float' },
    ],
  },
  {
    type: 'BME280',
    name: 'BME280 — Temp / Humidity / Pressure',
    description: 'I2C/SPI sensor. Temperature, humidity, and barometric pressure.',
    category: 'climate',
    dataFields: [
      { field: 'temperature', unit: '°C',  dataType: 'float' },
      { field: 'humidity',    unit: '%RH', dataType: 'float' },
      { field: 'pressure',    unit: 'hPa', dataType: 'float' },
    ],
  },
  {
    type: 'MQ2',
    name: 'MQ-2 — Gas / Smoke Sensor',
    description: 'Detects LPG, propane, hydrogen, smoke. Analog + digital outputs.',
    category: 'gas',
    dataFields: [
      { field: 'gasLevel', unit: 'ppm', dataType: 'float' },
      { field: 'alert',    unit: 'bool', dataType: 'boolean' },
    ],
  },
  {
    type: 'SOIL_MOISTURE',
    name: 'Soil Moisture Sensor',
    description: 'Capacitive or resistive soil moisture probe. Analog output (0–100%).',
    category: 'environment',
    dataFields: [
      { field: 'moisture', unit: '%', dataType: 'float' },
    ],
  },
];

async function main() {
  console.log('Seeding SensorTypeRegistry...');

  for (const st of sensorTypes) {
    await prisma.sensorTypeRegistry.upsert({
      where: { type: st.type },
      update: { ...st, dataFields: st.dataFields as any },
      create: { ...st, dataFields: st.dataFields as any },
    });
    console.log(`  ✓ ${st.type}`);
  }

  console.log(`\nSeeded ${sensorTypes.length} sensor types.`);
}

main()
  .catch((e) => { console.error(e); process.exit(1); })
  .finally(() => prisma.$disconnect());
