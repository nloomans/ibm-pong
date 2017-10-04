const router = require('express').Router();

router.get('/', (req, res) => {
  res.json({ text: 'hi' });
});

module.exports = router;
