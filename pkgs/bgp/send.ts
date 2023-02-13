import { sendBGPCarrierMessage } from './api';
const args = [...$vararg];
const destination = args[0];
const message = args[1];

if (!destination) throw new Error('No destination provided');
if (!message) throw new Error('No message provided');

const to = parseInt(destination);

if (isNaN(to)) throw new Error('Destination is not a number');

sendBGPCarrierMessage({
  from: os.getComputerID(),
  to,
  data: message,
});
