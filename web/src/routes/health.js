const express = require('express');
const router = express.Router();
const db = require('../db');

router.get('/health', async (req, res) => {
  try {
    await db.query('SELECT 1');
    res.status(200).send('OK');
  } catch (err) {
    res.status(500).send('Database connection error');
  }
});

module.exports = router;
