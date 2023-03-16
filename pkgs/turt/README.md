# Goals

- [x] Provide an API to control the turtle's movement
  - [x] The API will include all the basic turtle movements
  - [x] It will also include absolute positioning such as `lookTo(dir: string)` and `moveTo(x: number, y: number)`
  - [x] Inside the main class, it will keep track of it's absolute orientation and position
- [ ] Create an event system to trigger events at different stages of a turtle's journey
  - [ ] On obstruction
  - [ ] Before move
  - [ ] After move
  - [ ] Before step
  - [ ] After step
- [ ] Create a navigation system where a premade **job** can be set up that defines parameters such as:
  - [ ] **Working Area:** A rectangle that defines the area the turtle can work in
  - [ ] **Obstruction:** A 3D box that defines an area the turtle cannot work in
  - [ ] **Subtraction:** A 3D box that cuts through an **Obstruction** and allows the turtle to work in that area (a boolean subtraction)
  - [ ] **Dig:** A 3D box that defines an area the turtle will dig (does not matter if it is obstructed or not)
  - [ ] Each system counts as a **Zone**, which can contain a list of **actions** that the turtle will perform in that zone
  - [ ] Actions can be tied to specific events such as **beforeMove**, **afterMove**, etc
