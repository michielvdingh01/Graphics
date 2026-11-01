extends Resource
## Everything on sale in a level, as the level builder laid it out: see
## goods() in tools/kit/shop.gd for how it comes to stand there and
## scripts/goods.gd for what happens to it then.

## Numbers per thing on sale.
const STRIDE := 8
## In that order, each thing's: where its middle is (x, y and z), which way it faces in radians, the number of the product (see
## scripts/goods_catalog.gd), how it lies, how much of the light reaches it
## (0 to 1), and one more than the number of what it stands on, or 0 for what
## stands on a shelf, which does not go.
@export var items := PackedFloat32Array()
