const jwt = require('jsonwebtoken');
const jwksRsa = require('jwks-rsa');

// Cognito User Pool의 region과 userPoolId 입력
const region = 'ap-southeast-2'; // 예: ap-southeast-2
const userPoolId = 'ap-southeast-2_cnp2BD9AJ'; // 너의 실제 user pool id

const issuer = `https://cognito-idp.${region}.amazonaws.com/${userPoolId}`;

const client = jwksRsa({
  jwksUri: `${issuer}/.well-known/jwks.json`,
});

function getKey(header, callback) {
  client.getSigningKey(header.kid, function (err, key) {
    const signingKey = key.getPublicKey();
    callback(null, signingKey);
  });
}

exports.verifyToken = (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ message: '토큰이 없습니다.' });
  }

  const token = authHeader.split(' ')[1];

  jwt.verify(token, getKey, { algorithms: ['RS256'], issuer }, (err, decoded) => {
    if (err) {
      console.error('토큰 검증 실패:', err);
      return res.status(401).json({ message: '토큰이 유효하지 않습니다.' });
    }

    req.user = decoded; // 토큰 내용에서 사용자 정보 저장
    next();
  });
};
