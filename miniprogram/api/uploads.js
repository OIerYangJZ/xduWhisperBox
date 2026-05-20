import request from '../utils/request';
import { getData, resolveUrl } from '../utils/format';

const IMAGE_TYPES = {
  jpg: 'image/jpeg',
  jpeg: 'image/jpeg',
  png: 'image/png',
  webp: 'image/webp',
  gif: 'image/gif'
};

const fileNameFromPath = (filePath, fallback) => {
  const cleanPath = String(filePath || '').split('?')[0];
  const name = cleanPath.split('/').filter(Boolean).pop();
  return name || fallback;
};

const contentTypeFromName = (fileName) => {
  const ext = String(fileName || '').split('.').pop().toLowerCase();
  return IMAGE_TYPES[ext] || 'image/jpeg';
};

const readFileBase64 = (filePath) => {
  return new Promise((resolve, reject) => {
    wx.getFileSystemManager().readFile({
      filePath,
      encoding: 'base64',
      success: (res) => resolve(res.data),
      fail: reject
    });
  });
};

const uploadLocalImage = async (filePath, options = {}) => {
  const fileName = options.fileName || fileNameFromPath(filePath, 'image.jpg');
  const contentType = options.contentType || contentTypeFromName(fileName);
  const dataBase64 = await readFileBase64(filePath);
  const response = await request.post(options.url, {
    dataBase64,
    imageDataBase64: dataBase64,
    avatarDataBase64: dataBase64,
    fileName,
    contentType,
    avatarFileName: fileName,
    avatarContentType: contentType,
    ...(options.extra || {})
  });
  return getData(response, {});
};

export const uploadPostImage = async (filePath, options = {}) => {
  const upload = await uploadLocalImage(filePath, {
    ...options,
    url: '/api/uploads/images'
  });
  return {
    ...upload,
    url: resolveUrl(upload.url)
  };
};

export const uploadAvatarImage = async (filePath, options = {}) => {
  const upload = await uploadLocalImage(filePath, {
    ...options,
    url: '/api/users/avatar'
  });
  return {
    ...upload,
    avatarUrl: resolveUrl(upload.avatarUrl)
  };
};

export const uploadBackgroundImage = async (filePath, options = {}) => {
  const upload = await uploadLocalImage(filePath, {
    ...options,
    url: '/api/uploads/images'
  });
  return {
    ...upload,
    url: resolveUrl(upload.url)
  };
};
