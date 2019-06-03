breed[houses house]
breed[workZones workZone]
breed[breedingZones breedingZone]
breed[landmarks landmark]
breed[humans human]
breed[mosquitos mosquito]

globals[
  ;;Set Up variables
  xcord
  ycord
  groups
  names_houses
  wxcord
  wycord
  treexcoord
  treeycoord
  carxcoord
  carycoord

  ;;Mosquito Global Variables
  bloodfeed_cooldown
  bloodfeed_cooldown_disperson
  ages_female
  ages_male
  ages_wolbachia
  age_deviation ;;random-normal mean standard-deviation

  TICK_ADULT_DEATH_PROBABILITY
  TICK_EGG_DEATH_PROBABILITY
  mosquito_speed
  speed_deviation
  mosquito_movement_speed_deviation
  mosquito_night_movement_prob
  mosquito_movement_focus
  mosquito_detection_radius
  mosquito_action_radius
  eggs_laid
  eggs_laid_deviation
  emergence_death_prob

  ;;Human Global Variables
	human_movement_focus
	human_movement_speed
	human_movement_speed_deviation

  ;;Utility variables
  seconds_per_tick
  number_of_days
  half_day
  working_hour?
  weekend?
  total_bites_number
]


houses-own[
  group
  name ;;HDB Block Name
]

humans-own[
  group ;;Each human belongs to a HDB.
  workerstudent? ;;Whether he/she is in the neighbourhood.
  goWork?
  atWork?
]

workZones-own[
]

breedingZones-own[

]

mosquitos-own[
  age ;; Stores the mosquito age in ticks
  life_stage_ticks ;; V:Int: Stores the number of ticks a mosquito has spent in a given life stage
  life_stage ;; Stores the current life phase of the mosquito for behaviour purposes (0,1,2,3)

  transition_ages ;;Ensures that there is variation in mosquitos lifecycle.
  mated? ;; Stores the female state in mating (True/False)
  female? ;; Differentiates male mosquitos from females
  bloodfed? ;; Whether a female has bloodfed
  laidEggs? ;;  Stores the female state in oviposition
  wolbachia? ;;  Differentiates wolbachia mosquitos from non-wolbachia
  wolbachiaMate? ;; Stores if a female mated with a wolbachia-infected mate. This is so that eggs laid are 0.

  movement_speed ;;
  ovipositionCounter ;; V:Int: Counts the number of times a female has laid eggs
  maleReproductiveDelay ;; V:Int: Timer from egg hatching until the time when males are ready to mate

  feeding_cooldown ;;How long a mosquito will rest before feeding again
  gonotrophic_cooldown ;; Time required from bloodfeed until mosquito can lay eggs (oviposition is ready)
]

to set-global-variables
  set bloodfeed_cooldown 288 ;;24 Hours because each mosquito can only feed on blood once a day
  set bloodfeed_cooldown_disperson 0.15
  ;;Each tick is 300 seconds
  ;;From Egg to Larva, takes 1-2 Days to develop.   288-576 ticks
  ;;From Larva to Pupa, takes 4 Days.    1152 ticks
  ;;From Pupa to Adult, takes 2 Days.    576 ticks
  ;;From Female Adult to Death, takes 2 Weeks. 4032
  ;;For Male Adult to Death, takes 1 Week. 2016,

  set ages_female(list 0 576 1728 2304 6336)
  set ages_male (list 0 576 1728 2304 4320)
  set ages_wolbachia (list 0 576 1728 2304 3456)

  set age_deviation 288 ;; ;;Deviation of 1 day.

  ;;Mosquito Movement Variables
  set mosquito_speed 15 ;;Mosquitos move by 15 units when adult.
  set mosquito_movement_speed_deviation 0.25

  set mosquito_movement_focus 0.65
  set mosquito_detection_radius 22.5
  set mosquito_action_radius 7.5
  set mosquito_night_movement_prob 0.025 ;;2.5%

  set seconds_per_tick 300
  set number_of_days 0
  set half_day 144 ;;12 Hours

  set TICK_ADULT_DEATH_PROBABILITY 0.00025
	set TICK_EGG_DEATH_PROBABILITY 0.0000347222

  set eggs_laid 100
  set eggs_laid_deviation 0.15
  set total_bites_number 0
  set weekend? false

	set human_movement_focus 0.85

	set human_movement_speed 20
	set human_movement_speed_deviation 0.25

end

to setup
  clear-all
  reset-ticks
  set-global-variables
  setup-land
  set-coordinates
  create-workschoolzone
  create-humans-houses-breeding
  create-mosquito-population
end

to go
  update_days_number
  toggle_day_night

  ;Agents Actions
  act-mosquitos
  act-humans

  let tobereleased mosquito-per-resident * (count humans)

  if(strategy = "Weekly")[
  ;;If weekly, release tobereleased once a week. 3,6,9,12,15
  if(number_of_days MOD 7 = 0 )
    [release-wolbachia-mosquitoes tobereleased]
  ]

  if(strategy = "Biweekly")[
  if(number_of_days MOD 3.5 = 0 )
    [release-wolbachia-mosquitoes tobereleased / 2]
  ]

  if(strategy = "Daily")[
  if(ticks MOD 288 = 0 )
    [release-wolbachia-mosquitoes tobereleased / 7]
  ]

  if(strategy = "None")[
    ;;Nothing
  ]

  if(strategy = "Daily-Mixed")[
    if ticks >= 3000[
    set tobereleased (mosquito-per-resident - 6) * (count humans)
    ]
  if(ticks MOD 288 = 0 )
    [release-wolbachia-mosquitoes tobereleased / 7]
  ]

  tick
end

to act-mosquitos
 ask mosquitos
  [
    ifelse(working_hour?)
    [
      act-mosquito-day
    ][
      ;;At Night. 20% Chance of exhibiting daylight behavior as mosquitos can go indoors. Else will behave at night.
      ifelse(random-bool .2) ;;If false, act day. If true. act night.
      [act-mosquito-day]
      [act-mosquito-night]
    ]

    ;Death by natural processes
    if((age + life_stage_ticks > item 4 transition_ages))[die]

    ;Aging routines
    set age (age + 1)
    set life_stage_ticks (life_stage_ticks + 1)
  ]
end

to act-mosquito-day
  if(life_stage = 0)[act-egg]
  if(life_stage = 1)[act-larva]
  if(life_stage = 2)[act-pupa]
  if(life_stage = 3)[act-adult]
end

to act-mosquito-night
  if(life_stage = 0)[act-egg]
  if(life_stage = 1)[act-larva]
  if(life_stage = 2)[act-pupa]
  if(life_stage = 3)[act-adult-night]
end

to act-resetFemale
  set laidEggs? false
  set bloodfed? false
  set feeding_cooldown floor (random-normal bloodfeed_cooldown bloodfeed_cooldown_disperson)
end

to act-egg
  if(random-bool TICK_EGG_DEATH_PROBABILITY)[die]
  if(age + life_stage_ticks = item 1 transition_ages)[set life_stage  1 set life_stage_ticks 0]
end

to act-larva
  if(age + life_stage_ticks = item 2 transition_ages )
  [set life_stage  2 set life_stage_ticks 0]
end
to act-pupa
  if(age + life_stage_ticks = item 3 transition_ages)
  [set life_stage  3 set life_stage_ticks 0]
end

to act-adult
   probabilistic-natural-death
   ifelse(female? = false)
   [
      ;Male
      ifelse(maleReproductiveDelay != 0)
      [
         ;Pre-reproductive
         move-pseudo-random-walking ((movement_speed) / 10) mosquito_movement_speed_deviation
         set maleReproductiveDelay (maleReproductiveDelay - 1)
      ][
         act-reproductive
      ]
   ][
        act-reproductive
   ]
end
to act-adult-night
  if(random-bool mosquito_night_movement_prob)
  [
    move-pseudo-random-walking ((movement_speed) / 10) mosquito_movement_speed_deviation
  ]
end

to probabilistic-natural-death
  if(wolbachia? = False)[
      if(random-bool (1.5 * TICK_ADULT_DEATH_PROBABILITY))[die]
   ]
end

to act-reproductive
  if((mated? = false) and (laidEggs? = false) and (bloodfed? = false))[act-mate]
  if((female? = true) and (mated? = true))
  [
      ifelse(laidEggs? = false)
      [
          ifelse(bloodfed? = false)
      [act-not-bloodfed-yet]
          [act-bloodfed-yet]
      ][
          act-resetFemale
      ]
  ]
end

to act-mate
  ifelse(female? = true)
  [mate-as-female]
  [mate-as-male]
end

to mate-as-female
  let close_reproductive_males ((mosquitos in-radius 0.5) with [(female? = false) and (life_stage >= 3)])
  move-probabilistically-towards (min-one-of landmarks [distance myself]) (movement_speed) mosquito_movement_focus mosquito_movement_speed_deviation
  if((any? close_reproductive_males) and (random-bool .05))
  [
    set mated? true
    ifelse([wolbachia?] of (min-one-of close_reproductive_males [distance myself]))[set wolbachiaMate? true][set wolbachiaMate? false]
  ]
end

to mate-as-male
  let close_reproductive_females ((mosquitos in-radius mosquito_detection_radius) with [(female? = true) and (life_stage >= 3)])
  ifelse(any? close_reproductive_females)
  [move-probabilistically-towards (min-one-of close_reproductive_females [distance myself]) (movement_speed) mosquito_movement_focus mosquito_movement_speed_deviation]
  [move-probabilistically-towards (min-one-of landmarks [distance myself]) (movement_speed) mosquito_movement_focus mosquito_movement_speed_deviation];Move towards closest landmark
end

to act-layEggs
  let case 0
  let closest_breeding_zone (min-one-of breedingZones [distance myself])
  let closest_reproZone (min-one-of (turtle-set closest_breeding_zone) [distance myself])
  move-probabilistically-towards closest_reproZone (movement_speed) mosquito_movement_focus mosquito_movement_speed_deviation;Move towards closest breeding zone

  if((distance closest_reproZone) < mosquito_action_radius)
  [
      ifelse((wolbachiaMate?))[set case 1][set case 2] ;;ifelse((wolbachia? or wolbachiaMate?))[set case 1][set case 2]
      if(case = 1)[reproduce-wolbachia]
      if(case = 2)[reproduce-normal]
      set laidEggs? true
      set ovipositionCounter (ovipositionCounter + 1);
  ]
end

to reproduce-wolbachia
    if(wolbachiaMate?)[reproduce 0 false]
end

to reproduce-normal
    ;;If there is no breeding ground then eggs cannot lay.
    reproduce (random-normal eggs_laid eggs_laid_deviation) false
end

to reproduce [offspring_number wolbachia_bool]
  hatch-mosquitos offspring_number
  [
    set age 0
    set female? random-bool .4
    set size 0.5
    set wolbachia? wolbachia_bool
    set wolbachiaMate? false
    set mated? false
    set bloodfed? false
    set laidEggs? false
    set life_stage 0
    set transition_ages create_transition_ages
    set maleReproductiveDelay floor (convert_days_to_ticks (random-normal 1.5 .5))
    set feeding_cooldown floor (random-normal bloodfeed_cooldown .1)
    set ovipositionCounter 0
    set life_stage_ticks 0
  ]
end

to act-bloodfeed
  let closest_human (min-one-of (humans in-radius mosquito_detection_radius) [distance myself])
  ifelse(closest_human != nobody)
  [
    move-probabilistically-towards closest_human (movement_speed) mosquito_movement_focus mosquito_movement_speed_deviation;Move towards closest human
    if (((distance closest_human) < mosquito_action_radius) and (random-bool .001));If a human is within the action radius feed on him
    [
      ifelse(wolbachiaMate? = false)
      [
        set total_bites_number (total_bites_number + 1)
        set bloodfed? true
      ][
        ;;no dengue but still bitten
        set total_bites_number (total_bites_number + 1)
        set bloodfed? true
      ]

    ]
  ][
     move-pseudo-random-walking (movement_speed / 10) mosquito_movement_speed_deviation
  ]
end

to act-not-bloodfed-yet
   ;;Once a female has mated (one-time only event) check if feeding cooldown (set to around one day after laying eggs) has come to zero
   ifelse(feeding_cooldown = 0)
   [act-bloodfeed]
   [
       move-pseudo-random-walking ((movement_speed) / 10) mosquito_movement_speed_deviation
       set feeding_cooldown (feeding_cooldown - 1)
   ]
end
to act-bloodfed-yet
    act-layEggs
end

to move-pseudo-random-walking [speed deviation_speed]
  left random-integer-between -180 179 ;;turns left or right by a certain degree.
  let random-speed random-float speed
  forward random-speed
end

to move-probabilistically-towards [target speed probability deviation_speed]
  if(target != nobody)
  [
    ifelse(random-bool probability)
    [
      let distanceTemp ([distance myself] of target)
      if( ([distance myself] of target) != 0)
      [
        set heading (towards target)
        ifelse(distanceTemp > speed)[forward speed][forward distanceTemp]
      ]
    ]
    [
      move-pseudo-random-walking speed deviation_speed
    ]
  ]
end

to act-humans
  ask humans[
    ifelse(working_hour?)[act-human-day][act-human-night]
  ]
end

to act-human-day
    ifelse(workerstudent? = FALSE)[act-human-non-worker][act-human-worker]
end

to act-human-worker
   ifelse(goWork? = TRUE)
   [
       move-probabilistically-towards one-of workZones human_movement_speed human_movement_focus human_movement_speed_deviation
       set shape "person business"
       set atWork? true
   ][
    set atWork? false
    wander-around-house group (human_movement_speed / 4) human_movement_focus human_movement_speed_deviation
   ]
end

to act-human-non-worker
      wander-around-house group (human_movement_speed / 4) human_movement_focus human_movement_speed_deviation
end

to act-human-night
  set atWork? false
  if((any? (houses with [group = group]) in-radius 2) = False)[wander-around-house group human_movement_speed human_movement_focus human_movement_speed_deviation]
  set goWork? True
end

to wander-around-house [groupName speed probability deviation_speed]
  if(group = groupName)[move-probabilistically-towards (one-of houses with [group = groupName]) speed probability deviation_speed]


end

to release-wolbachia-mosquitoes [number]
    create-mosquitos number[
    set size 0.5
    set shape "bug"
    set color green
    set wolbachia? true

    ;;Creating mosquitoes near the breeding zones
    while[(count (breedingZones in-radius 2) = 0)][setRandomXY]

    ;;These 2 variables are to create some variation in the behavior of the mosquitoes. ie, each mosquito has different movement patterns and ages.
    set movement_speed abs (random-normal mosquito_speed speed_deviation)
    set transition_ages create_transition_ages

    set laidEggs? false
    set feeding_cooldown floor (random bloodfeed_cooldown)

    set life_stage_ticks 0

    set maleReproductiveDelay floor (convert_days_to_ticks (random-normal 1.5 .5))
    set female? false
    set wolbachiaMate? false
    set ovipositionCounter 0

    set life_stage 3
    set age 2304 ;;Males Wolbachia survives on average 4 days
    set mated? false
    set bloodfed? false

  ]

end

to setup-land

  import-drawing "Yishun.png"

  set treexcoord (list -75 -21 -101 -85 -86 111)
  set treeycoord (list 22  40 -68 -74 -61 -56)

  (foreach treexcoord treeycoord[ [txc tyc] ->
  create-turtles 1[
   setxy txc tyc
   set shape "tree"
      set size 10
      set color green
  ]])

  set carxcoord (list -110 -26 24 136 100 -90 -140 1)
    set carycoord (list -20 15 60 -48 50 48 47 -31)


  (foreach carxcoord carycoord[ [cxc cyc] ->
  create-turtles 1[
   setxy cxc cyc
   set shape "car"
      set size 7
      set color red
  ]])
end

to set-coordinates
	;set xcord (list 61 -39 -56 -7 52 -71 18 -5 68 38 73 85 -112 -141)
   ; set ycord (list 37 32 16 -6 -6 -11 -15 -18 -24 -29 -39 -53 -65 -74)

  set xcord (list 50 -39 -103 -123 -31 -81 15 18 60 82 135 77 44 -107)
  set ycord (list 63 32 1 26 61 -35 2 -41 -60 -20 3 30 93 -88)

	set groups
(list 1 2 3 4 5 6 7 8 9 10 11 12 13 14)
	set names_houses
  (list "BLK633" "BLK630" "BLK627" "BLK628" "BLK629" "BLK855" "BLK858" "BLK863" "BLK864" "BLK861" "BLK860" "BLK859" "BLK632" "BLK853")
	set wxcord
(list 140)
	set wycord
(list 90)
end

to create-workschoolzone
  (foreach wxcord wycord[ [wxc wyc] ->
    create-workZones 1[
      setxy wxc wyc
      set size 15
      set color green
      set shape "house"
      set pcolor grey
      set label "Workplace"
      set label-color black
    ]
  ])

  ask patches with [pxcor >= 130 and pxcor <= 150 and pycor >= 79 and pycor <= 100] [
  set pcolor (grey + random 3)
]
end

to create-humans-houses-breeding
  let house_name_counter 0
  (foreach xcord ycord groups  [ [xc yc gr ] ->
    create-house-at-coordinates (xc) (yc) (gr) (item house_name_counter names_houses)
    set house_name_counter (house_name_counter + 1)
    create-breeding-zone-around-coordinates (xc) (yc)
    create-humans-at-houses (gr)
  ])
end

to create-house-at-coordinates [xcoord ycoord groupIn nameIn]
  create-houses 1[
    setxy xcoord ycoord
    set group groupIn
    set name nameIn
    set size 20
    set color 36
    set shape "house"
    set label-color black
    set label name
  ]
end

to create-breeding-zone-around-coordinates [xcoord ycoord]
  ;;We assume breeding zones to be only at HDB flats
  let xbreeding 2 * max-pxcor
  let ybreeding 2 * min-pxcor
  while[(xbreeding >= max-pxcor - 5) or (ybreeding >= max-pycor - 5) or (xbreeding <= min-pxcor + 5) or (ybreeding <= min-pycor + 5)][
    set xbreeding (random-normal xcoord 2)
    set ybreeding (random-normal ycoord 2)
  ]

  create-breedingZones 1
  [
    setxy (random-normal xbreeding 1) (random-normal ybreeding 1)
    set size 6
    set color blue
    set shape "circle"
    set label-color black
    set label "Breeding Zone"

    ;;set probOfSurvival 1.0
  ]

  create-landmarks 1
  [
    setxy (random-normal xbreeding 1) (random-normal ybreeding 1)
    set size 4
    set color yellow
    set shape "target"
  ]

end

to create-humans-at-houses [groupIn]
  ;;For each house, there are about 150 housholds. About 600 People per house
  ;;We assume for each household, at most half go to school/work
    create-humans initialNumPerHDB[ ;;For testing purposes, create 10 humans per HDB.
        set group groupIn
        while[count houses in-radius 0 with[group = groupIn] = 0][setRandomXY]
        set size 4
        set shape "person"
        set heading 90
        set color red
        ifelse (random-float 1 < 0.5)
        [set workerstudent? FALSE set goWork? FALSE][set workerstudent? TRUE set goWork? TRUE]
        set atWork? FALSE
    ]
end

to create-mosquito-population
  create-mosquitos mosquito-popn
  [
    set size 0.5
    set shape "bug"
    set color orange

    ;;Creating mosquitoes near the breeding zones
    while[(count (breedingZones in-radius 2) = 0)][setRandomXY]

    set laidEggs? false
    set feeding_cooldown floor (random bloodfeed_cooldown)

    ;;These 2 variables are to create some variation in the behavior of the mosquitoes. ie, each mosquito has different movement patterns and ages.
    set movement_speed abs (random-normal mosquito_speed speed_deviation)

    ;;So far the mosquitos have not been through any time.
    set life_stage_ticks 0

    set maleReproductiveDelay floor (convert_days_to_ticks (random-normal 1.5 .5))
    ifelse (random-float 1 < 0.5)
    [set female? true][set female? false]
    set wolbachiaMate? false
    set ovipositionCounter 0
    set wolbachia? false
    set transition_ages create_transition_ages

    let lifeRand random 10 ;;10% of the initial population eggs, 10% larvae, 20% Pupa and 60% Mosquitos.
    if(lifeRand > 0 and lifeRand <= 1)[set life_stage 0] ;;EGG
    if(lifeRand > 1 and lifeRand <= 2)[set life_stage 1] ;;LARVAE
    if(lifeRand > 2 and lifeRand <= 4)[set life_stage 2] ;;PUPAE
    if(lifeRand > 4)[set life_stage 3] ;;ADULT

    ;;Setting the initial ages.
    if(life_stage = 0)[set age (random-integer-between 0 576)] ;;Between 1 and 2 Days
    if(life_stage = 1)[set age (random-integer-between 576 1152)] ;;Between 2 and 4 Days
    if(life_stage = 2)[set age (random-integer-between 1152 1728)] ;;Between 4 and 6 days

    ifelse(female? = true)[
    if(life_stage = 3)[set age (random-integer-between 1728 4032)] ;;Between 6 days and 1 week Weeks
    ][
      set age (random-integer-between 1728 2016)
    ]

    ifelse(life_stage = 3 and female?)
    [
       ifelse (random-float 1 < 0.5)[set mated? true][set mated? false] ;;Set half of the mosquitos as mated and half as not.
       ifelse(mated?)[ifelse (random-float 1 < 0.5)[set bloodfed? true][set bloodfed? false]] ;;If mated, set half of them as having a bloodfed.
      [set bloodfed? false]
    ][
        set mated? false
        set bloodfed? false
    ]
  ]
end

to-report create_transition_ages
  if(female? = true)[
  report (
        ;;0 576 1152 576 4032
        ;;0 576 1728 2304 6336
            list
            transition-age-variation (item 0 ages_female) 0;EggInit
            transition-age-variation (item 1 ages_female) age_deviation;EggEnd-LarvaInit 576
            transition-age-variation (item 2 ages_female) age_deviation;LarvaEnd-PupaInit 1152
            transition-age-variation (item 3 ages_female) age_deviation;PupaEnd-AdultInit 576
            transition-age-variation (item 4 ages_female) age_deviation;AdultEnd-Death 4032
         )
  ]

  if(female? = false)[
  report (
        ;;0 576 1152 576 4032
        ;;0 576 1728 2304 6336
            list
            transition-age-variation (item 0 ages_male) 0;EggInit
            transition-age-variation (item 1 ages_male) age_deviation;EggEnd-LarvaInit 576
            transition-age-variation (item 2 ages_male) age_deviation;LarvaEnd-PupaInit 1152
            transition-age-variation (item 3 ages_male) age_deviation;PupaEnd-AdultInit 576
            transition-age-variation (item 4 ages_male) age_deviation;AdultEnd-Death 4032
         )
  ]

  if(wolbachia? = true)[
  report (
        ;;0 576 1152 576 4032
        ;;0 576 1728 2304 6336
            list
            transition-age-variation (item 0 ages_wolbachia) 0;EggInit
            transition-age-variation (item 1 ages_wolbachia) age_deviation;EggEnd-LarvaInit 576
            transition-age-variation (item 2 ages_wolbachia) age_deviation;LarvaEnd-PupaInit 1152
            transition-age-variation (item 3 ages_wolbachia) age_deviation;PupaEnd-AdultInit 576
            transition-age-variation (item 4 ages_wolbachia) age_deviation;AdultEnd-Death 4032
         )
  ]
end

to-report random-integer-between [minNumber maxNumber]
  report (random (maxNumber - minNumber)) + minNumber
end

to-report transition-age-variation [transition-age deviation]
  ;;random-normal mean standard-deviation
  report abs (floor (random-normal transition-age deviation))
end

to toggle_weekend
  ifelse(((floor number_of_days) mod 6 = 0) or ((floor number_of_days) mod 7 = 0))[set weekend? True][set weekend? False]
end
to toggle_day_night
  if(ticks mod half_day = 0) ;;144, 288,
  [ifelse(working_hour? = True)
    [set working_hour? False]
    [set working_hour? True]
  ]
end

to-report random-bool [skew] ;;0.025
  ifelse(random-float 1 > skew)[report false ][report true]
end

to setRandomXY
  setxy (random-integer-between (- max-pxcor) max-pxcor) (random-integer-between (- max-pycor) max-pycor)
end

to-report convert_days_to_ticks [days]
  report days * 24 * 60 * 60 * (1 / seconds_per_tick)
end

to update_days_number
  set number_of_days (ticks / (half_day * 2))
end
@#$#@#$#@
GRAPHICS-WINDOW
211
10
1035
564
-1
-1
2.711443
1
10
1
1
1
0
0
0
1
-150
150
-100
100
0
0
1
ticks
30.0

BUTTON
6
14
73
48
Setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
81
15
144
48
Go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
1051
100
1299
145
No. Male Adult Mosquitoes (Non-Wolbachia)
count mosquitos with [female? = false AND wolbachia? = false AND life_stage = 3]
17
1
11

MONITOR
1313
100
1482
145
No. Female Adult Mosquitoes
count turtles with [shape = \"bug\" AND female? = true AND life_stage = 3]
17
1
11

MONITOR
1053
159
1227
204
No. Wolbachia Mosquitoes
count mosquitos with [wolbachia? = true AND life_stage = 3]
17
1
11

MONITOR
1246
158
1384
203
Total Mosquito Bites
TOTAL_BITES_NUMBER
17
1
11

PLOT
1055
279
1283
439
Mosquitoes Over Time
Time
Mosquitoes
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"female" 1.0 0 -2674135 true "" "plot count mosquitos with [female? = true AND wolbachia? = false AND life_stage = 3]"
"male" 1.0 0 -13345367 true "" "plot count mosquitos with [female? = false AND wolbachia? = false AND life_stage = 3]"
"wolbachia" 1.0 0 -11085214 true "" "plot count mosquitos with [wolbachia? = true]"

TEXTBOX
7
160
174
180
No. of Residents per HDB
13
0.0
1

MONITOR
7
56
91
101
Days Elapsed
NUMBER_OF_DAYS
2
1
11

MONITOR
103
56
177
101
Weekend?
WEEKEND?
17
1
11

TEXTBOX
8
322
216
354
Wolbachia Mitigation Strategy\n
13
0.0
1

SLIDER
4
287
202
320
mosquito-per-resident
mosquito-per-resident
0
10
3.0
1
1
NIL
HORIZONTAL

CHOOSER
2
339
141
384
strategy
strategy
"Weekly" "Biweekly" "Daily" "Daily-Mixed" "None"
0

MONITOR
1053
479
1267
524
No. Residents in Neighbourhood
count humans with [atwork? = false]
17
1
11

MONITOR
1290
479
1438
524
No. Residents at Work
count humans with [atwork? = true]
17
1
11

SLIDER
5
232
201
265
mosquito-popn
mosquito-popn
0
1000
400.0
100
1
NIL
HORIZONTAL

PLOT
1296
279
1548
438
Population Demographic
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Egg" 1.0 0 -2674135 true "" "plot count mosquitos with[life_stage = 0]"
"Larva" 1.0 0 -13840069 true "" "plot count mosquitos with[life_stage = 1]"
"Pupa" 1.0 0 -13791810 true "" "plot count mosquitos with[life_stage = 2]"
"Adult" 1.0 0 -817084 true "" "plot count mosquitos with[life_stage = 3 AND wolbachia? = false]"

TEXTBOX
9
215
159
233
Mosquitos Population\n
13
0.0
1

MONITOR
6
112
94
157
WorkingHour?
WORKING_HOUR?
17
1
11

BUTTON
148
15
204
48
Go
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
1050
43
1117
88
No. Eggs
Count Mosquitos with [life_stage = 0]
17
1
11

MONITOR
1129
42
1200
87
No. Larva
count mosquitos with [life_stage = 1]
17
1
11

MONITOR
1214
41
1281
86
No. Pupa
count mosquitos with [life_stage = 2]
17
1
11

MONITOR
1293
40
1364
85
No. Adults
count mosquitos with [life_stage = 3 AND wolbachia? = false]
17
1
11

MONITOR
1055
219
1214
264
No. Bloodfed Mosquitos
count mosquitos with[ bloodfed? = true]
17
1
11

MONITOR
1230
218
1372
263
No. Mated Mosquitos
count mosquitos with[ mated? = true]
17
1
11

SLIDER
6
178
202
211
initialNumPerHDB
initialNumPerHDB
0
100
20.0
1
1
NIL
HORIZONTAL

TEXTBOX
4
386
207
558
Strategy Legend\nWeekly - Mosquitos are released once a week\nBiweekly - Mosquitos are released once every two weeks\nDaily - Mosquitos are released daily\nDaily-Mixed - Mosquitos are released daily until ticks a treshold is met and the number of mosquitos are reduced\nNone - No mosquitos are being released
11
14.0
1

TEXTBOX
6
269
207
287
No. of Mosquitos per Resident
13
0.0
1

TEXTBOX
1218
14
1368
33
Mosquitos
15
104.0
1

TEXTBOX
1233
452
1383
471
Residents
15
124.0
1

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

person business
false
0
Rectangle -1 true false 120 90 180 180
Polygon -13345367 true false 135 90 150 105 135 180 150 195 165 180 150 105 165 90
Polygon -7500403 true true 120 90 105 90 60 195 90 210 116 154 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 183 153 210 210 240 195 195 90 180 90 150 165
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 76 172 91
Line -16777216 false 172 90 161 94
Line -16777216 false 128 90 139 94
Polygon -13345367 true false 195 225 195 300 270 270 270 195
Rectangle -13791810 true false 180 225 195 300
Polygon -14835848 true false 180 226 195 226 270 196 255 196
Polygon -13345367 true false 209 202 209 216 244 202 243 188
Line -16777216 false 180 90 150 165
Line -16777216 false 120 90 150 165

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.4
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="BetweenStrategies" repetitions="30" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>NUMBER_OF_DAYS = 30</exitCondition>
    <metric>Count Mosquitos with [life_stage = 0]</metric>
    <enumeratedValueSet variable="mosquito-per-resident">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="strategy">
      <value value="&quot;Daily-Mixed&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquito-popn">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initialNumPerHDB">
      <value value="20"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
