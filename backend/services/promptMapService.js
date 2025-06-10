// 🔸 프롬프트 → AI 태그 매핑표
const promptMap = {
  '음식': ['food', 'fruit', 'cup'],
  '동물': ['dog', 'cat', 'animal', 'fish', 'bird'],
  '풍경': ['tree', 'river', 'mountain', 'sky', 'beach', 'sun', 'moon', 'scene', 'plant'],
  '사람': ['woman', 'man', 'girl', 'boy', 'people', 'portrait'],
  '여행': ['car', 'bus', 'road', 'bicycle', 'building', 'pool', 'mountain', 'beach'],
  '셀카': ['portrait', 'face', 'selfie']
};

// 🔹 contentTags + simpleTags 합쳐서 비교
const matchesUserPrompt = (photo, userPrompts) => {
  const allTags = new Set([...(photo.contentTags || []), ...(photo.simpleTags || [])]);

  for (const prompt of userPrompts) {
    const keywords = promptMap[prompt] || [];
    if (keywords.some(k => allTags.has(k))) return true;
  }
  return false;
};

module.exports = {
  promptMap,
  matchesUserPrompt
};
