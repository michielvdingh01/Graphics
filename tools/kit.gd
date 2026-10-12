extends "res://tools/kit/rooms.gd"
## The kit: everything that is built in code and can stand in any level. A
## level extends this file, or its plan does.
##
## GDScript cannot make one script out of several files, so the drawers of
## the kit are a chain, each extending the one before it:
##
##   tools/level_builder.gd   walls, props, lights, decals, the route, and
##                            the geometry builders everything is made with
##   tools/kit/parts.gd       what machines are put together from: beams,
##                            flanges, bolts, handwheels, motors, gauges
##   tools/kit/machines.gd    tank(), press(), lathe(), workbench(), crane()
##   tools/kit/plant.gd       boiler(), pump(), gauge_board()
##   tools/kit/fittings.gd    doorway(), corridor_services(), notice_board()
##   tools/kit/power.gd       turbine(), transformer(), switchboard(),
##                            control_desk(), the masts and lines of a
##                            substation, cable_ladder()
##   tools/kit/structure.gd   roof() in five forms, from a slab to trusses
##                            and a sawtooth, pier(), plinth(), buttress()
##   tools/kit/services.gd    pipe_run(), duct_run(), sprinkler_line(),
##                            cable_tray(), radiator(), sign_plate(),
##                            wall_lamp(), pin_board(), hang()
##   tools/kit/furniture.gd   filing_cabinets(), counter(), bench(),
##                            shelving(), kitchen_range(), screens(),
##                            plate_rack(), cable_drum(), cases(),
##                            spray_booth()
##   tools/kit/rooms.gd       a level laid out as rooms: room(), door(),
##                            window(), fight(), build_rooms()
##
## Something new goes into the drawer it belongs in, or into a new one before
## the last, which lays out rooms with everything the others hold. A piece
## takes where it stands and what it stands against as arguments and knows
## nothing of the level it is used in. tools/levels/showroom.gd sets the kit
## out side by side, to judge a piece from close by without building and
## baking a level.
