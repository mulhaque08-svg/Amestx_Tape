$itemCodes = @(
    # 100 Series - Earthwork & Site Prep
    @{ itemCode = "100"; category = "100 Series - Earthwork"; title = "Preparing Right of Way"; specBook = "2024 / 2014"; description = "Preparing right of way by clearing, grubbing, removing, and disposing of trees, brush, and obstructions." }
    @{ itemCode = "104"; category = "100 Series - Earthwork"; title = "Removing Concrete"; specBook = "2024 / 2014"; description = "Breaking, removing, and disposing of existing concrete pavement, curb, gutter, sidewalks, or structures." }
    @{ itemCode = "105"; category = "100 Series - Earthwork"; title = "Removing Treated & Untreated Base & Asphalt Pavement"; specBook = "2024 / 2014"; description = "Removing existing flexible base, treated base, or asphalt concrete pavement." }
    @{ itemCode = "106"; category = "100 Series - Earthwork"; title = "Obliterating Abandoned Road"; specBook = "2024 / 2014"; description = "Obliterating abandoned roadways, backfilling ditches, and restoring ground surface." }
    @{ itemCode = "110"; category = "100 Series - Earthwork"; title = "Excavation"; specBook = "2024 / 2014"; description = "Excavating roadway, channels, and structural foundations, including haul and disposal." }
    @{ itemCode = "112"; category = "100 Series - Earthwork"; title = "Subgrade Widening"; specBook = "2024 / 2014"; description = "Excavating and preparing roadbed widening for subgrade layers." }
    @{ itemCode = "132"; category = "100 Series - Earthwork"; title = "Embankment"; specBook = "2024 / 2014"; description = "Constructing roadway embankments using suitable earth, rock, or approved materials." }
    @{ itemCode = "134"; category = "100 Series - Earthwork"; title = "Backfilling Pavement Edges"; specBook = "2024 / 2014"; description = "Backfilling edges of pavement using flexible base, topsoil, or select material." }
    @{ itemCode = "150"; category = "100 Series - Earthwork"; title = "Blading"; specBook = "2024 / 2014"; description = "Blading and shaping slopes, shoulders, ditches, or subgrade with motor grader." }
    @{ itemCode = "160"; category = "100 Series - Earthwork"; title = "Topsoil"; specBook = "2024 / 2014"; description = "Furnishing and placing topsoil for vegetation growth and slope stabilization." }
    @{ itemCode = "161"; category = "100 Series - Earthwork"; title = "Compost"; specBook = "2024 / 2014"; description = "Furnishing and applying compost manufactured topsoil or compost erosion control blankets." }
    @{ itemCode = "162"; category = "100 Series - Earthwork"; title = "Sodding for Erosion Control"; specBook = "2024 / 2014"; description = "Furnishing and placing approved Bermuda or native grass sod for erosion control." }
    @{ itemCode = "164"; category = "100 Series - Earthwork"; title = "Seeding for Erosion Control"; specBook = "2024 / 2014"; description = "Furnishing and applying seed mixes, fertilizer, and mulch for temporary or permanent erosion control." }
    @{ itemCode = "168"; category = "100 Series - Earthwork"; title = "Vegetative Watering"; specBook = "2024 / 2014"; description = "Applying water to promote growth of seeded, sodded, or sprigged areas." }
    @{ itemCode = "169"; category = "100 Series - Earthwork"; title = "Soil Retention Blankets"; specBook = "2024 / 2014"; description = "Furnishing and installing biodegradable or synthetic soil retention blankets on slopes." }

    # 200 Series - Subgrade & Base Courses
    @{ itemCode = "247"; category = "200 Series - Subgrade & Base"; title = "Flexible Base"; specBook = "2024 / 2014"; description = "Constructing flexible base courses using crushed stone, gravel, or caliche." }
    @{ itemCode = "251"; category = "200 Series - Subgrade & Base"; title = "Reworking Base Courses"; specBook = "2024 / 2014"; description = "Scarifying, pulverizing, reshaping, compacting, and finishing existing base courses." }
    @{ itemCode = "260"; category = "200 Series - Subgrade & Base"; title = "Lime Treatment (Road-Mixed)"; specBook = "2024 / 2014"; description = "Treating subgrade or base material with hydrated lime or quicklime by road mixing." }
    @{ itemCode = "275"; category = "200 Series - Subgrade & Base"; title = "Cement Treatment (Road-Mixed)"; specBook = "2024 / 2014"; description = "Treating subgrade or base material with hydraulic cement by road mixing." }
    @{ itemCode = "276"; category = "200 Series - Subgrade & Base"; title = "Cement Treatment (Plant-Mixed)"; specBook = "2024 / 2014"; description = "Constructing base courses composed of aggregate and hydraulic cement mixed in a central plant." }
    @{ itemCode = "292"; category = "200 Series - Subgrade & Base"; title = "Asphalt Treatment (Plant-Mixed)"; specBook = "2024 / 2014"; description = "Constructing base courses composed of aggregate and asphalt binder mixed in a central plant." }

    # 300 Series - Surface Courses & Bituminous Pavements
    @{ itemCode = "310"; category = "300 Series - Surface Courses"; title = "Prime Coat"; specBook = "2024 / 2014"; description = "Applying asphaltic material to prepared base course prior to surface placement." }
    @{ itemCode = "316"; category = "300 Series - Surface Courses"; title = "Seal Coat"; specBook = "2024 / 2014"; description = "Applying single or multiple applications of asphalt binder and aggregate for surface treatment." }
    @{ itemCode = "340"; category = "300 Series - Surface Courses"; title = "Dense-Graded Hot-Mix Asphalt (Small Quantity)"; specBook = "2024 / 2014"; description = "Constructing dense-graded hot-mix asphalt (HMA) pavement for small quantity applications." }
    @{ itemCode = "341"; category = "300 Series - Surface Courses"; title = "Dense-Graded Hot-Mix Asphalt"; specBook = "2024 / 2014"; description = "Constructing dense-graded hot-mix asphalt surface or binder courses (Type B, C, D, F)." }
    @{ itemCode = "344"; category = "300 Series - Surface Courses"; title = "Superpave Mixtures"; specBook = "2024 / 2014"; description = "Constructing hot-mix asphalt pavement using Superpave volumetric mix design." }
    @{ itemCode = "346"; category = "300 Series - Surface Courses"; title = "Stone-Matrix Asphalt"; specBook = "2024 / 2014"; description = "Constructing stone-matrix asphalt (SMA) wearing surface courses." }
    @{ itemCode = "347"; category = "300 Series - Surface Courses"; title = "Thin Overlay Mixtures (TOM)"; specBook = "2024 / 2014"; description = "Constructing thin overlay asphalt mixtures (Type F and Type C TOM)." }
    @{ itemCode = "348"; category = "300 Series - Surface Courses"; title = "Thin Bonded Friction Courses"; specBook = "2024 / 2014"; description = "Constructing permeable friction courses (PFC) or thin bonded wearing courses." }
    @{ itemCode = "351"; category = "300 Series - Surface Courses"; title = "Flexible Pavement Structure Repair"; specBook = "2024 / 2014"; description = "Repairing localized areas of failed flexible pavement structure." }
    @{ itemCode = "354"; category = "300 Series - Surface Courses"; title = "Planing and Texturing Pavement"; specBook = "2024 / 2014"; description = "Milling, planing, and texturing existing asphalt or concrete pavement surfaces." }
    @{ itemCode = "360"; category = "300 Series - Surface Courses"; title = "Concrete Pavement"; specBook = "2024 / 2014"; description = "Constructing Portland cement concrete pavement (CRCP or JCP)." }

    # 400 Series - Structures & Culverts
    @{ itemCode = "400"; category = "400 Series - Structures"; title = "Excavation and Backfill for Structures"; specBook = "2024 / 2014"; description = "Excavating and backfilling for bridge bents, abutments, culverts, and retaining walls." }
    @{ itemCode = "401"; category = "400 Series - Structures"; title = "Flowable Backfill"; specBook = "2024 / 2014"; description = "Furnishing and placing low-strength flowable backfill for utility trenches and structures." }
    @{ itemCode = "402"; category = "400 Series - Structures"; title = "Trench Excavation Protection"; specBook = "2024 / 2014"; description = "Furnishing and installing trench shoring, shielding, or excavation safety systems." }
    @{ itemCode = "403"; category = "400 Series - Structures"; title = "Temporary Special Shoring"; specBook = "2024 / 2014"; description = "Designing, constructing, and removing temporary special shoring walls." }
    @{ itemCode = "416"; category = "400 Series - Structures"; title = "Drilled Shaft Foundations"; specBook = "2024 / 2014"; description = "Constructing reinforced concrete drilled shaft foundations for bridges and sign structures." }
    @{ itemCode = "420"; category = "400 Series - Structures"; title = "Concrete Substructures"; specBook = "2024 / 2014"; description = "Constructing cast-in-place concrete substructure bents, columns, caps, and abutments." }
    @{ itemCode = "422"; category = "400 Series - Structures"; title = "Concrete Superstructures"; specBook = "2024 / 2014"; description = "Constructing cast-in-place reinforced concrete bridge decks and slab spans." }
    @{ itemCode = "423"; category = "400 Series - Structures"; title = "Retaining Walls"; specBook = "2024 / 2014"; description = "Constructing mechanically stabilized earth (MSE), precast, or cast-in-place retaining walls." }
    @{ itemCode = "425"; category = "400 Series - Structures"; title = "Precast Prestressed Concrete Structural Members"; specBook = "2024 / 2014"; description = "Furnishing and erecting precast prestressed concrete TxGirders, I-girders, and box beams." }
    @{ itemCode = "432"; category = "400 Series - Structures"; title = "Riprap"; specBook = "2024 / 2014"; description = "Constructing concrete, stone, or grouted riprap for slope protection and culverts." }
    @{ itemCode = "442"; category = "400 Series - Structures"; title = "Metal for Structures"; specBook = "2024 / 2014"; description = "Furnishing and fabricating structural steel girders, plate girders, and diaphragms." }
    @{ itemCode = "450"; category = "400 Series - Structures"; title = "Railing"; specBook = "2024 / 2014"; description = "Constructing concrete or metal bridge railings (SSTR, T223, T551, C223)." }
    @{ itemCode = "462"; category = "400 Series - Structures"; title = "Concrete Box Culverts and Drains"; specBook = "2024 / 2014"; description = "Furnishing and installing precast or cast-in-place reinforced concrete box culverts." }
    @{ itemCode = "464"; category = "400 Series - Structures"; title = "Reinforced Concrete Pipe"; specBook = "2024 / 2014"; description = "Furnishing and installing reinforced concrete pipe (RCP) for culverts and storm drains." }
    @{ itemCode = "465"; category = "400 Series - Structures"; title = "Junction Boxes, Manholes, and Inlets"; specBook = "2024 / 2014"; description = "Constructing junction boxes, storm sewer manholes, drop inlets, and curb inlets." }
    @{ itemCode = "466"; category = "400 Series - Structures"; title = "Headwalls and Wingwalls"; specBook = "2024 / 2014"; description = "Constructing cast-in-place or precast headwalls and wingwalls for pipe and box culverts." }
    @{ itemCode = "467"; category = "400 Series - Structures"; title = "Safety End Treatment"; specBook = "2024 / 2014"; description = "Constructing safety end treatments (SET) for pipe and box culvert ends." }
    @{ itemCode = "479"; category = "400 Series - Structures"; title = "Adjusting Manholes and Inlets"; specBook = "2024 / 2014"; description = "Adjusting existing manhole covers, inlet rings, and grates to finished grade." }

    # 500 Series - Incidentals & Traffic Management
    @{ itemCode = "500"; category = "500 Series - Incidentals"; title = "Mobilization"; specBook = "2024 / 2014"; description = "Establishing field offices, moving equipment to site, and initial work setup." }
    @{ itemCode = "502"; category = "500 Series - Incidentals"; title = "Barricades, Signs, and Traffic Handling"; specBook = "2024 / 2014"; description = "Furnishing, installing, maintaining, and moving traffic control devices and barricades." }
    @{ itemCode = "506"; category = "500 Series - Incidentals"; title = "Temporary Erosion, Sedimentation, and Environmental Controls"; specBook = "2024 / 2014"; description = "Installing silt fence, rock filter dams, construction exits, and SWP3 controls." }
    @{ itemCode = "508"; category = "500 Series - Incidentals"; title = "Constructing Detours"; specBook = "2024 / 2014"; description = "Constructing, maintaining, and removing temporary traffic detours." }
    @{ itemCode = "512"; category = "500 Series - Incidentals"; title = "Portable Traffic Barrier"; specBook = "2024 / 2014"; description = "Furnishing, moving, and connecting portable concrete traffic barrier (PCTB)." }
    @{ itemCode = "529"; category = "500 Series - Incidentals"; title = "Concrete Curb, Gutter, and Combined Curb and Gutter"; specBook = "2024 / 2014"; description = "Constructing hydraulic cement concrete curb, gutter, or combined curb and gutter." }
    @{ itemCode = "530"; category = "500 Series - Incidentals"; title = "Intersections, Driveways, and Turnouts"; specBook = "2024 / 2014"; description = "Constructing concrete or asphalt driveway approaches, turnouts, and street intersections." }
    @{ itemCode = "531"; category = "500 Series - Incidentals"; title = "Sidewalks"; specBook = "2024 / 2014"; description = "Constructing concrete sidewalks and ADA curb ramps." }
    @{ itemCode = "536"; category = "500 Series - Incidentals"; title = "Concrete Medians and Directional Islands"; specBook = "2024 / 2014"; description = "Constructing concrete medians, raised islands, and traffic separators." }
    @{ itemCode = "540"; category = "500 Series - Incidentals"; title = "Metal Beam Guard Fence"; specBook = "2024 / 2014"; description = "Furnishing and erecting steel W-beam guardrail on timber or composite posts." }
    @{ itemCode = "542"; category = "500 Series - Incidentals"; title = "Removing Metal Beam Guard Fence"; specBook = "2024 / 2014"; description = "Removing and stockpiling or disposing of existing metal beam guard fence." }
    @{ itemCode = "544"; category = "500 Series - Incidentals"; title = "Guardrail End Treatments"; specBook = "2024 / 2014"; description = "Furnishing and installing crashworthy guardrail end treatments (GET / SGT)." }
    @{ itemCode = "545"; category = "500 Series - Incidentals"; title = "Crash Cushion Attenuators"; specBook = "2024 / 2014"; description = "Furnishing, installing, and moving re-directive or non-redirective crash cushion attenuators." }
    @{ itemCode = "550"; category = "500 Series - Incidentals"; title = "Chain Link Fence"; specBook = "2024 / 2014"; description = "Furnishing and constructing chain link security fence and gates." }
    @{ itemCode = "552"; category = "500 Series - Incidentals"; title = "Wire Fence"; specBook = "2024 / 2014"; description = "Furnishing and constructing barbed wire or woven wire field fence." }
    @{ itemCode = "560"; category = "500 Series - Incidentals"; title = "Mailbox Assemblies"; specBook = "2024 / 2014"; description = "Furnishing and mounting single or multiple crashworthy mailbox supports." }

    # 600 Series - Lighting, Signals, Signs & Markings
    @{ itemCode = "610"; category = "600 Series - Lighting & Signals"; title = "Roadway Illumination Assemblies"; specBook = "2024 / 2014"; description = "Furnishing and erecting roadway illumination poles, mast arms, and LED luminaires." }
    @{ itemCode = "618"; category = "600 Series - Lighting & Signals"; title = "Conduit"; specBook = "2024 / 2014"; description = "Furnishing and installing PVC, HDPE, or metallic electrical conduit underground or attached to structures." }
    @{ itemCode = "620"; category = "600 Series - Lighting & Signals"; title = "Electrical Conductors"; specBook = "2024 / 2014"; description = "Furnishing and pulling insulated electrical conductors and ground wires." }
    @{ itemCode = "624"; category = "600 Series - Lighting & Signals"; title = "Ground Boxes"; specBook = "2024 / 2014"; description = "Furnishing and installing electrical ground boxes and aprons." }
    @{ itemCode = "628"; category = "600 Series - Lighting & Signals"; title = "Electrical Services"; specBook = "2024 / 2014"; description = "Installing electrical service enclosures, meters, and utility connections." }
    @{ itemCode = "636"; category = "600 Series - Lighting & Signals"; title = "Signs"; specBook = "2024 / 2014"; description = "Furnishing and installing guide, warning, and regulatory signs on roadside supports." }
    @{ itemCode = "644"; category = "600 Series - Lighting & Signals"; title = "Small Roadside Sign Assemblies"; specBook = "2024 / 2014"; description = "Furnishing, fabricating, and erecting small roadside sign supports and stub posts." }
    @{ itemCode = "647"; category = "600 Series - Lighting & Signals"; title = "Large Roadside Sign Supports and Assemblies"; specBook = "2024 / 2014"; description = "Erecting large roadside sign supports, breakaway I-beams, and sign panels." }
    @{ itemCode = "662"; category = "600 Series - Lighting & Signals"; title = "Work Zone Pavement Markings"; specBook = "2024 / 2014"; description = "Furnishing and placing temporary work zone paint, tape, or removable pavement markings." }
    @{ itemCode = "666"; category = "600 Series - Lighting & Signals"; title = "Retroreflectorized Pavement Markings"; specBook = "2024 / 2014"; description = "Furnishing and applying thermoplastic or multipolymer retroreflectorized pavement stripes." }
    @{ itemCode = "672"; category = "600 Series - Lighting & Signals"; title = "Raised Pavement Markers"; specBook = "2024 / 2014"; description = "Furnishing and placing reflectorized raised pavement markers (Jiggle buttons / RPMs)." }
    @{ itemCode = "677"; category = "600 Series - Lighting & Signals"; title = "Eliminating Existing Pavement Markings and Markers"; specBook = "2024 / 2014"; description = "Removing or blacking out obsolete pavement stripes and markers." }
    @{ itemCode = "680"; category = "600 Series - Lighting & Signals"; title = "Highway Traffic Signals"; specBook = "2024 / 2014"; description = "Installing traffic signal controllers, cabinets, and complete signalized intersections." }
    @{ itemCode = "682"; category = "600 Series - Lighting & Signals"; title = "Vehicle Signal Heads"; specBook = "2024 / 2014"; description = "Furnishing and mounting 3-section or 5-section LED vehicle traffic signal heads." }
    @{ itemCode = "684"; category = "600 Series - Lighting & Signals"; title = "Traffic Signal Cables"; specBook = "2024 / 2014"; description = "Furnishing and pulling multi-conductor traffic signal cable." }

    # 700 Series - Maintenance
    @{ itemCode = "700"; category = "700 Series - Maintenance"; title = "Pothole Repair"; specBook = "2024 / 2014"; description = "Cleaning, tacking, and filling localized potholes with approved asphalt mix." }
    @{ itemCode = "712"; category = "700 Series - Maintenance"; title = "Cleaning and Sealing Joints and Cracks (Asphalt Concrete)"; specBook = "2024 / 2014"; description = "Cleaning and hot-pour rubber sealant filling of pavement cracks and joints." }
    @{ itemCode = "730"; category = "700 Series - Maintenance"; title = "Roadside Mowing"; specBook = "2024 / 2014"; description = "Mowing highway right of way, center medians, and roadside slopes." }
    @{ itemCode = "734"; category = "700 Series - Maintenance"; title = "Litter Removal"; specBook = "2024 / 2014"; description = "Collecting and disposing of trash and debris along highway right of way." }
    @{ itemCode = "738"; category = "700 Series - Maintenance"; title = "Cleaning and Sweeping Highways"; specBook = "2024 / 2014"; description = "Sweeping and vacuuming debris from highway gutters, paved shoulders, and medians." }
    @{ itemCode = "770"; category = "700 Series - Maintenance"; title = "Guard Fence Repair"; specBook = "2024 / 2014"; description = "Repairing damaged metal beam guard fence rail elements, posts, and end treatments." }
)

# Sort by Item Code number
$sortedCodes = $itemCodes | Sort-Object { [int]$_.itemCode }

$jsonPath = "downloads/item_codes.json"
$sortedCodes | ConvertTo-Json -Depth 5 | Set-Content -Path $jsonPath -Encoding UTF8
Write-Host "Created item_codes.json with $($sortedCodes.Count) standard TxDOT Item Codes!"
