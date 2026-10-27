const express = require('express');
const { listCounters, addCounter, removeCounter } = require('../controllers/counterController');
const { protect } = require('../middleware/auth');

const router = express.Router();

router.use(protect);

// Takeaway/Delivery counters: anyone at the counter can see, add and remove
// them, so a counter added on one device shows on every device.
router.get('/', listCounters);
router.post('/:type', addCounter);
router.delete('/:type/:number', removeCounter);

module.exports = router;
