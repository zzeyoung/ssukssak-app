// swagger.js
const swaggerJSDoc = require('swagger-jsdoc');

const options = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: '쓱싹 API 명세서',
      version: '1.0.0',
      description: '쓱싹 백엔드 API 문서입니다.',
    },
    servers: [
      {
        url: 'http://localhost:3000',
        description: '로컬 개발 서버',
      },
    ],
  },
  apis: ['./routes/*.js',
    './app.js',
    './controllers/*.js',
  ], // 경로는 라우터 주석이 있는 곳
};

const specs = swaggerJSDoc(options);
module.exports = specs;
