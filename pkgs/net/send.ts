// import softlink from "./softlink";

// const args = [...$vararg];
// const data = tostring(args[0]);
// const destinations = args.slice(1).map(Number);

// const modem = peripheral.find("modem")[0]! as ModemPeripheral;

// softlink.send(modem, { destinations, data });

// import peripheral, { PeripheralKind } from 'cc/peripheral';
// import { BASE } from 'bgp/api';

// const args = [...$vararg];
// const destination_ = args[0];
// const via_ = args[1];

// if (destination_ === undefined) throw 'No destination provided';
// if (via_ === undefined) throw 'No message provided';

// const destination = parseInt(destination_);
// const via = parseInt(via_);

// if (isNaN(destination)) throw 'Destination is not a number';
// if (isNaN(via)) throw 'Via is not a number';

// const message = BASE.create(destination, via);

// peripheral
//   .find(PeripheralKind.Modem)
//   .forEach((modem) => modem.transmit(1, 2, message));
