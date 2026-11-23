module.exports = {
  port: Number(process.env.PORT || 3000),
  simulationEnabled: process.env.DEMO_SIMULATION === 'true',
};
