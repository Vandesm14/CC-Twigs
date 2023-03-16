# Goals

1. Provide an API to control the turtle's movement
   1. The API will include all the basic turtle movements
   2. It will also include absolute positioning such as `lookTo(dir: string)` and `moveTo(x: number, y: number)`
   3. Inside the main class, it will keep track of it's absolute orientation and position
2. Create a navigation system where a premade **job** can be set up that defines parameters such as:
   1. **Working Area:** A rectangle that defines the area the turtle can work in
   2. **Obstruction:** A 3D box that defines an area the turtle cannot work in
   3. **Subtraction:** A 3D box that cuts through an **Obstruction** and allows the turtle to work in that area (a boolean subtraction)
   4. **Dig:** A 3D box that defines an area the turtle will dig (does not matter if it is obstructed or not)
   5. Each system counts as a **Zone**, which can contain a list of **actions** that the turtle will perform in that zone
   6. Actions can be tied to specific events such as **beforeMove**, **afterMove**, etc
