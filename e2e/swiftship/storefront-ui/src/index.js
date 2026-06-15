const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

app.get('/health', (req, res) => {
  res.json({ status: 'UP', service: 'storefront-ui' });
});

app.get('/api/products', (req, res) => {
  res.json([
    { id: 1, name: 'Express Shipping Box', price: 9.99 },
    { id: 2, name: 'Overnight Envelope', price: 14.99 },
  ]);
});

app.listen(PORT, () => {
  console.log(`SwiftShip storefront running on port ${PORT}`);
});
