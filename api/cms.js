const { getSettings } = require('./_cmsStore');

module.exports = async (req, res) => {
  if (req.method !== 'GET') {
    return res.status(405).json({ success: false, error: 'Method not allowed' });
  }

  try {
    const settings = await getSettings();
    res.setHeader('Cache-Control', 'no-store, max-age=0');
    return res.status(200).json({
      success: true,
      content: settings.content
    });
  } catch (error) {
    console.error('CMS read failed:', error.message);
    return res.status(500).json({ success: false, error: 'CMS content unavailable' });
  }
};
