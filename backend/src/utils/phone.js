const separators = /[\s()-]/g;
const allowedCharacters = /^[+\d\s()-]+$/;
const mobilePhone = /^(?:\+?51)?(9\d{8})$/;

function normalizePhone(value) {
  if (typeof value !== 'string' || value.length > 64) return null;

  const trimmed = value.trim();
  if (!trimmed) return '';
  if (!allowedCharacters.test(trimmed)) return null;

  const match = mobilePhone.exec(trimmed.replace(separators, ''));
  return match ? `+51${match[1]}` : null;
}

module.exports = { normalizePhone };
