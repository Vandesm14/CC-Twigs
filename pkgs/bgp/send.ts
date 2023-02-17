import peripheral, { PeripheralKind } from 'cc/peripheral';
import { BASE } from './api';

const args = [...$vararg];
const destination_ = args[0];
const via_ = args[1];
const channel_ = args[2] ?? "1";
const replyChannel_ = args[3] ?? "2";

if (destination_ === undefined) throw 'No destination provided';
if (via_ === undefined) throw 'No via provided';

const destination = parseInt(destination_);
const via = parseInt(via_);
const channel = parseInt(channel_);
const replyChannel = parseInt(replyChannel_);

if (isNaN(destination)) throw 'Destination is not a number';
if (isNaN(via)) throw 'Via is not a number';
if (isNaN(channel)) throw 'Channel is not a number';
if (isNaN(replyChannel)) throw 'Reply channel is not a number';

const message = BASE.create(destination, via);

peripheral
  .find(PeripheralKind.Modem)
  .forEach((modem) => modem.transmit(channel, replyChannel, message));
