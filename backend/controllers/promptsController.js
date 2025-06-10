// 📁 controllers/promptsController.js

// 🔹 [GET] /user/prompts/init
// ✅ 앱 최초 실행 시, 사용자에게 제시할 프롬프트 태그 리스트 반환
// 📌 프론트는 이 리스트 중에서 사용자 취향에 맞는 태그들을 선택하게 됨
exports.getInitialPrompts = (req, res) => {
  const prompts = [
    "음식",   // 음식 사진
    "동물",   // 반려동물, 동물 관련 사진
    "풍경",   // 자연, 여행지 풍경 등
    "사람",   // 인물 사진
    "여행",   // 여행지 및 이동 중 사진
    "셀카"    // 셀프 카메라
  ];

  return res.status(200).json({
    message: "✅ 초기 프롬프트 태그 리스트 조회 성공",
    data: prompts,
  });
};
