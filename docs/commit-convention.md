# 📝 쓱싹 프로젝트 커밋 메시지 작성 규칙

쓱싹(SSUKSSAK) 프로젝트는 Git 커밋 메시지 규칙을 통일하여  
협업 시 커밋 내역을 명확하게 기록하고, 변경 이력을 효율적으로 추적할 수 있도록 합니다.

---

## ✅ 커밋 메시지 기본 형식

\`\`\`
[태그]: 한 줄 요약 (마침표 ❌, 소문자 사용)
\`\`\`

### ✏️ 예시

\`\`\`bash
feat: 이미지 중요도 기반 삭제 추천 기능 추가
\`\`\`

GitHub Desktop에서는 다음과 같이 작성합니다:

- **Summary**: \`[태그]: 작업 내용\`
- **Description (선택)**: 변경 이유, 목적 등을 간략히 작성

---

## ✅ 커밋 태그 목록

| 태그       | 설명                                         |
|------------|----------------------------------------------|
| \`init\`     | 프로젝트 초기 설정, 폴더 구조 생성 등        |
| \`feat\`     | 새로운 기능 추가                              |
| \`fix\`      | 버그 수정                                     |
| \`docs\`     | 문서 작성/수정 (README, 규칙 문서 등)         |
| \`style\`    | 코드 스타일 수정 (세미콜론, 공백 등)          |
| \`refactor\` | 리팩토링 (기능 변화 없이 코드 구조 개선)      |
| \`test\`     | 테스트 코드 추가 또는 수정                    |
| \`chore\`    | 기타 작업 (환경 설정, 패키지 설치 등)         |

---

## ✅ 커밋 메시지 예시

| 작업 내용                               | 커밋 메시지 예시                                 |
|----------------------------------------|--------------------------------------------------|
| 초기 폴더 구조 생성 및 .gitkeep 추가   | \`init: 프로젝트 폴더 구조 생성 및 .gitkeep 추가\` |
| Flutter 앱 초기 프로젝트 생성          | \`init: Flutter 프로젝트 생성\`                   |
| 이미지 중요도 추론 기능 추가           | \`feat: 이미지 중요도 추론 기능 추가\`            |
| 중복 필터링 오류 수정                  | \`fix: 중복 이미지 필터링 오류 수정\`             |
| README에 앱 소개 작성                  | \`docs: 쓱싹 앱 개요 및 폴더 구조 설명 추가\`     |
| 콘솔 로그 제거 및 들여쓰기 정리        | \`style: 콘솔 로그 제거 및 코드 포맷팅\`          |
| AWS S3 업로드 구조 리팩토링            | \`refactor: S3 업로드 로직 구조 개선\`            |
| .env.example 파일 추가                 | \`chore: 환경 변수 예시 파일 추가\`               |
| MobileNet 추론 테스트 코드 추가        | \`test: MobileNet 추론 테스트 추가\`              |

---

## ✅ 커밋 메시지 작성 시 유의사항

- 커밋 요약은 **50자 이내**로 간결하게 작성합니다.
- 마침표(\`.\`)는 붙이지 않습니다.
- 문장은 명령형이 아닌 **요약형**으로 작성합니다.
- 한글/영문 중 하나로 **팀에서 통일**합니다.
- Description(선택)은 변경 목적, 배경, 영향 등을 자유롭게 작성합니다.

---

## 🧪 GitHub Desktop 기준 워크플로우

1. 파일 수정 후 GitHub Desktop 실행
2. 변경 사항 확인
3. **Summary**에 커밋 메시지 작성  
   예: \`feat: 이미지 흐릿도 필터 기능 추가\`
4. **Description**(선택): 변경 목적이나 추가 설명
5. \`Commit to main\` 클릭 → \`Push origin\` 클릭

---

## 💡 좋은 커밋 메시지를 쓰는 팁

- **무엇을** 변경했는지 뿐 아니라, **왜** 변경했는지도 포함하기
- 커밋 로그만 봐도 프로젝트 흐름이 보이도록 작성하기
- 리뷰어에게 설명하듯 작성하기

---

본 규칙은 쓱싹 프로젝트 전체 기간 동안 사용되며,  
필요 시 팀 협의 후 업데이트될 수 있습니다 ✨
