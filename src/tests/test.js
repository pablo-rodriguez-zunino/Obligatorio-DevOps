import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: 3,          // 3 Usuarios Virtuales simultáneos
  duration: '10s', // La prueba dura solo 10 segundos (súper superficial)
  thresholds: {
    http_req_failed: ['rate<0.01'], // El test falla si más del 1% de las peticiones dan error
  },
};

export default function () {
  // Buscamos la URL de la app desde una variable de entorno que inyectará el pipeline
  const url = __ENV.APP_URL || 'http://localhost';
  
  const res = http.get(url);
  
  check(res, {
    'status es 200': (r) => r.status === 200,
  });

  sleep(1);
}
