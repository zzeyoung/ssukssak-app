# 🧹 쓱싹 (SSUKSSAK) 앱

**쓱싹**은 스마트폰 속 방대한 사진들을 자동으로 정리해주는 친환경 앱입니다.  
AI 모델을 기반으로 중복 사진, 흐릿한 사진, 불필요한 스크린샷 등을 감지하여 사용자에게 삭제를 추천하고,
나아가 AI 기반으로 개인화된 삭제 추천을 합니다.
이를 통해 디지털 탄소 발자국을 줄이는 데 기여합니다.

---

## 📱 핵심 기능

- 흐릿한/중복/스크린샷 등 사진 자동 분류
- AI 기반 중요도 판단 및 개인화된 삭제 추천
- 깔끔한 UI로 간편한 사진 정리 경험 제공
- 삭제를 통해 저장 공간 확보 및 환경 보호 실천

---

## 👨‍👩‍👧‍👦 팀 역할 분담



---

## 📁 폴더 구조

```plaintext
ssukssak-app/
├── ai/                     # AI 모델 학습 및 추론 코드
│   ├── model/              # 저장된 모델 파일
│   ├── inference/          # 온디바이스 추론용 코드
│   └── training/           # 학습 스크립트 및 노트북
│
├── aws/                    # AWS 인프라 구성 및 설정 (Lambda, S3, DynamoDB 등)
│
├── backend/                # Node.js 기반 백엔드 서버
│   ├── controllers/        # API 요청 처리 로직
│   └── service/            # 비즈니스 로직 및 AWS SDK 통신
│
├── frontend/               # Flutter 기반 모바일 앱
│   └── ssukssak_flutter/   # Flutter 프로젝트 루트
│
├── docs/                   # 기획서, API 명세서, 피드백 등 문서
├── README.md               # 프로젝트 설명 파일
└── .gitignore              # Git 무시 파일 설정


---

📣 **팀원에게 안내**

커밋을 작성하기 전에 반드시 [`commit-convention.md`](./docs/commit-convention.md) 문서를 읽어주세요.  
팀 전체가 일관된 커밋 메시지 규칙을 따르면 협업이 훨씬 수월해집니다!
