const { DynamoDBClient, BatchWriteItemCommand, ScanCommand } = require('@aws-sdk/client-dynamodb');
const axios = require('axios');
const client = new DynamoDBClient({ region: 'ap-northeast-2' });

// 한정 구역을 주소로부터 검색 (API KEY 기본)
async function getRegionNameFromCoords(lat, lon) {
  try {
    const res = await axios.get('https://maps.apigw.ntruss.com/map-reversegeocode/v2/gc', {
      params: {
        coords: `${lon},${lat}`,
        orders: 'legalcode',
        output: 'json'
      },
      headers: {
        'x-ncp-apigw-api-key-id': process.env.NCP_CLIENT_ID,
        'x-ncp-apigw-api-key': process.env.NCP_CLIENT_SECRET
      }
    });

    const region = res.data.results?.[0]?.region;
    return `${region?.area1?.name || ''} ${region?.area2?.name || ''}`.trim();

  } catch (err) {
    console.error('❌ 역지오코디드 실패:', err?.response?.data || err.message);
    return null;
  }
}

// 사진 분류 결과 저장
exports.saveClassificationResult = async (userId, photos) => {
  const now = new Date().toISOString();

  const items = await Promise.all(photos.map(async (photo) => {
    const { photoId, tags, filename, location } = photo;
    const folders = [];
    let groupId = null;
    let sourceApp = null;
    const contentTags = photo.contentTags || [];

    if (location?.lat && location?.lon) {
      const regionName = await getRegionNameFromCoords(location.lat, location.lon);
      console.log('📍 역지오코디드 결과:', regionName);
      const travelRegions = ['제주', '부산', '강릉', '속쳐', '여수', '경주', '전주', '남해'];
      if (regionName && travelRegions.some(r => regionName.includes(r))) {
        if (!contentTags.includes('여행')) contentTags.push('여행');
      }
    }

    if (photo.duplicateGroupId) {
      folders.push('완전 중복');
      groupId = photo.duplicateGroupId;
    } else {
      if (photo.similarGroupId) {
        folders.push('유사한 사진');
        groupId = photo.similarGroupId;
      }
      if (tags?.blurry === 1) {
        folders.push('흐릴한 사진');
      }
      if (filename?.includes('Screenshot_')) {
        folders.push('스크립샷');
        const match = filename.match(/Screenshot_\d+_\d+_(.+?)\./);
        if (match) sourceApp = match[1];
      }
      if (tags?.low_score <= 0.35) {
        folders.push('삭제 추천');
      }
    }

    return {
      userId,
      photoId,
      folder: folders.join(','),
      timestamp: now,
      tags,
      contentTags,
      groupId,
      sourceApp,
      location: photo.location || null,
      imageSize: photo.imageSize || null
    };
  }));

  await exports.saveClassifications(items);
};

// DynamoDB 저장
exports.saveClassifications = async (items) => {
  const tableName = 'PhotoTags';
  const batches = [];

  while (items.length) {
    const batch = items.splice(0, 25);

    const requestItems = batch.map(item => {
      const baseItem = {
        userId: { S: item.userId },
        photoId: { S: item.photoId },
        folder: { S: item.folder },
        timestamp: { S: item.timestamp },
        tags: {
          M: Object.fromEntries(
            Object.entries(item.tags).map(([k, v]) => [k, { N: v.toString() }])
          )
        }
      };
      // ✅ contentTags 저장
      if (item.contentTags && item.contentTags.length > 0) {
        baseItem.contentTags = { SS: item.contentTags };
      }
      // ✅ groupId 저장
      if (item.groupId) {
        baseItem.groupId = { S: item.groupId };
      }
      // ✅ sourceApp 저장
      if (item.sourceApp) {
        baseItem.sourceApp = { S: item.sourceApp };
      }
      if(item.locatio?.lat && item.location?.lon){
        baseItem.location = {
          M: {
            lat: { N: item.location.lat.toString() },
            lon: { N: item.location.lon.toString() }
          }
        };
      }
      // ✅ [추가] 이미지 크기 저장
    if (item.imageSize?.width && item.imageSize?.height) {
      baseItem.imageSize = {
        M: {
          width: { N: item.imageSize.width.toString() },
          height: { N: item.imageSize.height.toString() }
        }
      };
    }

      return { PutRequest: { Item: baseItem } };
    });

    batches.push({ RequestItems: { [tableName]: requestItems } });
  }

  for (const batch of batches) {
    await client.send(new BatchWriteItemCommand(batch));
  }
};

// 전체 분류 결과 조회
exports.fetchClassificationResult = async (userId) => {
  const tableName = 'PhotoTags';

  const command = new ScanCommand({
    TableName: tableName,
    FilterExpression: 'userId = :uid',
    ExpressionAttributeValues: {
      ':uid': { S: userId }
    }
  });

  const result = await client.send(command);

  return result.Items.map(item => ({
    userId: item.userId.S,
    photoId: item.photoId.S,
    folder: item.folder.S,
    timestamp: item.timestamp.S,
    tags: Object.fromEntries(
      Object.entries(item.tags.M).map(([k, v]) => [k, parseFloat(v.N)])
    ),
    contentTags: item.contentTags?.SS || [],
    groupId: item.groupId?.S || null,
    sourceApp: item.sourceApp?.S || null
  }));
};

// 단일 사진 분류할 때 포르더 판단
exports.getFolderFromTags = (photo) => {
  const tags = photo.tags || {};
  const filename = photo.filename || '';
  const folders = [];
  let sourceApp = null;

  if (photo.duplicateGroupId) {
    return { folder: '완전 중복', sourceApp: null };
  }

  if (photo.similarGroupId) {
    folders.push('유사한 사진');
  }

  if (tags.blurry === 1) {
    folders.push('흐릴한 사진');
  }

  if (filename.includes('Screenshot_')) {
    folders.push('스크립샷');
    const match = filename.match(/Screenshot_\d+_\d+_(.+?)\./);
    if (match) sourceApp = match[1];
  }

  if (tags.low_score >= 0.85) {
    folders.push('삭제 추천');
  }

  return {
    folder: folders.length > 0 ? folders.join(',') : '기타',
    sourceApp
  };
};
