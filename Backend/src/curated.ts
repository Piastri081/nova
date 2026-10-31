export interface CuratedTitle {
  id: string;
  title: string;
  year: number;
  genres: string[];
  rating: number;
  runtimeMinutes: number;
  blurb: string;
  tags: string[];
  popularity: number;
}

/**
 * The catalog is intentionally curated. Every entry points at an Internet
 * Archive item that hosts a public-domain or Creative Commons film.
 *
 * To add a licensed source later, add a provider in catalog.ts rather than
 * scraping an unauthorized streaming site.
 */
export const CURATED: CuratedTitle[] = [
  {
    id: "Night.Of.The.Living.Dead_1080p",
    title: "Night of the Living Dead",
    year: 1968,
    genres: ["Horror", "Thriller"],
    rating: 7.9,
    runtimeMinutes: 96,
    blurb:
      "Strangers barricade themselves inside a rural farmhouse as the recently dead rise and close in. George A. Romero's landmark independent horror film still feels raw, claustrophobic, and dangerous.",
    tags: ["essential", "horror", "featured"],
    popularity: 100
  },
  {
    id: "charade-1963-cary-grant-audrey-hepburn-comedy-mystery-romance-thriller-full-movie",
    title: "Charade",
    year: 1963,
    genres: ["Thriller", "Comedy", "Romance"],
    rating: 7.9,
    runtimeMinutes: 113,
    blurb:
      "A newly widowed woman in Paris is pursued by men who believe her late husband stole a fortune. A charming stranger offers help, but everyone in this stylish thriller is hiding something.",
    tags: ["essential", "featured"],
    popularity: 98
  },
  {
    id: "his_girl_friday",
    title: "His Girl Friday",
    year: 1940,
    genres: ["Comedy", "Drama", "Romance"],
    rating: 7.9,
    runtimeMinutes: 92,
    blurb:
      "A newspaper editor will do anything to stop his ace reporter and ex-wife from remarrying. The dialogue flies faster than the typewriters in one of Hollywood's sharpest screwball comedies.",
    tags: ["essential"],
    popularity: 95
  },
  {
    id: "Nosferatu_most_complete_version_93_mins.",
    title: "Nosferatu",
    year: 1922,
    genres: ["Horror", "Silent"],
    rating: 7.9,
    runtimeMinutes: 94,
    blurb:
      "A real-estate agent travels to a remote castle and awakens an ancient hunger that follows him home. F. W. Murnau's shadow-drenched vampire film remains the blueprint for cinematic dread.",
    tags: ["essential", "silent", "horror"],
    popularity: 94
  },
  {
    id: "metropolis-1927-full-movie-4-k-color-remastered-2023-colorized-with-gottfried-huppertz-score",
    title: "Metropolis",
    year: 1927,
    genres: ["Sci-Fi", "Silent", "Drama"],
    rating: 8.3,
    runtimeMinutes: 148,
    blurb:
      "In a future city split between gleaming towers and a subterranean workforce, a wealthy son discovers the machine that keeps the world running. Fritz Lang's monumental vision of technology and class.",
    tags: ["essential", "silent", "scifi"],
    popularity: 92
  },
  {
    id: "carnival_of_souls_202110",
    title: "Carnival of Souls",
    year: 1962,
    genres: ["Horror", "Mystery"],
    rating: 7.1,
    runtimeMinutes: 78,
    blurb:
      "After surviving a car crash, a young organist moves to a new town and is drawn toward an abandoned pavilion. A dreamlike cult horror film with an ending that lingers.",
    tags: ["essential", "horror"],
    popularity: 90
  },
  {
    id: "TheGeneral1926",
    title: "The General",
    year: 1926,
    genres: ["Comedy", "Silent", "Action"],
    rating: 8.1,
    runtimeMinutes: 79,
    blurb:
      "A railroad engineer chases his stolen locomotive and the woman he loves through the Civil War South. Buster Keaton's precise, death-defying comedy is a masterclass in visual storytelling.",
    tags: ["essential", "silent"],
    popularity: 88
  },
  {
    id: "sherlock-jr-1924-tmdb992",
    title: "Sherlock Jr.",
    year: 1924,
    genres: ["Comedy", "Silent"],
    rating: 8.2,
    runtimeMinutes: 45,
    blurb:
      "A film projectionist dreams himself into the detective movie on screen. Buster Keaton bends reality with practical effects that still look impossible.",
    tags: ["silent", "comedy"],
    popularity: 86
  },
  {
    id: "Detour_movie",
    title: "Detour",
    year: 1945,
    genres: ["Film Noir", "Drama"],
    rating: 7.3,
    runtimeMinutes: 68,
    blurb:
      "A piano player hitchhiking to California is pulled into a spiral of bad luck, stolen identity, and murder. Poverty-row noir with a fatalistic punch far above its budget.",
    tags: ["essential", "noir"],
    popularity: 84
  },
  {
    id: "d.-o.-a.-1950",
    title: "D.O.A.",
    year: 1949,
    genres: ["Film Noir", "Mystery"],
    rating: 7.2,
    runtimeMinutes: 83,
    blurb:
      "An accountant learns he has been poisoned and has only days to find his own killer. A race against the clock through smoky bars, office towers, and bad decisions.",
    tags: ["noir"],
    popularity: 82
  },
  {
    id: "thestranger1946_202004",
    title: "The Stranger",
    year: 1946,
    genres: ["Film Noir", "Thriller"],
    rating: 7.3,
    runtimeMinutes: 95,
    blurb:
      "A war-crimes investigator tracks a fugitive to a quiet Connecticut town, where a respected professor is living a carefully constructed lie. Orson Welles directs and stars.",
    tags: ["noir"],
    popularity: 80
  },
  {
    id: "kansascityconfidencial",
    title: "Kansas City Confidential",
    year: 1952,
    genres: ["Film Noir", "Crime"],
    rating: 7.2,
    runtimeMinutes: 99,
    blurb:
      "An innocent delivery driver is framed for a bank robbery and hunts the masked crew that set him up. Tough, twisty, and full of rain-slicked bad luck.",
    tags: ["noir"],
    popularity: 78
  },
  {
    id: "Hitch_Hiker",
    title: "The Hitch-Hiker",
    year: 1953,
    genres: ["Film Noir", "Thriller"],
    rating: 7.0,
    runtimeMinutes: 71,
    blurb:
      "Two friends on a fishing trip pick up a drifter who turns out to be a killer. Ida Lupino's taut road thriller tightens the screws with every mile.",
    tags: ["noir"],
    popularity: 76
  },
  {
    id: "The_Big_Combo_1955",
    title: "The Big Combo",
    year: 1955,
    genres: ["Film Noir", "Crime"],
    rating: 7.4,
    runtimeMinutes: 87,
    blurb:
      "A police detective becomes obsessed with bringing down a polished crime boss. Shadowy, sensual, and ruthless, with one of noir's great final images.",
    tags: ["noir"],
    popularity: 74
  },
  {
    id: "TheLittleShopOfHorrors",
    title: "The Little Shop of Horrors",
    year: 1960,
    genres: ["Comedy", "Horror"],
    rating: 6.9,
    runtimeMinutes: 72,
    blurb:
      "A meek flower-shop clerk cultivates a talking plant with an appetite for people. Roger Corman's scrappy comedy was shot fast and has been loved ever since.",
    tags: ["comedy", "horror"],
    popularity: 72
  },
  {
    id: "ABucketofBlood",
    title: "A Bucket of Blood",
    year: 1959,
    genres: ["Comedy", "Horror"],
    rating: 7.0,
    runtimeMinutes: 66,
    blurb:
      "A coffee-shop busboy accidentally becomes the beat scene's hottest sculptor. A black comedy about art, ambition, and what people will overlook for a headline.",
    tags: ["comedy", "horror"],
    popularity: 70
  },
  {
    id: "the-cabinet-of-dr-caligari-1920_202501",
    title: "The Cabinet of Dr. Caligari",
    year: 1920,
    genres: ["Horror", "Silent", "Mystery"],
    rating: 8.0,
    runtimeMinutes: 77,
    blurb:
      "A sinister showman and his sleepwalking subject haunt a town of crooked streets and painted shadows. The defining work of German Expressionist cinema.",
    tags: ["essential", "silent", "horror"],
    popularity: 68
  },
  {
    id: "ThePhantomoftheOpera",
    title: "The Phantom of the Opera",
    year: 1925,
    genres: ["Horror", "Silent", "Drama"],
    rating: 7.6,
    runtimeMinutes: 93,
    blurb:
      "A masked figure living beneath the Paris Opera fixates on a young singer. Lon Chaney's self-designed makeup and the subterranean sets made this a silent-era sensation.",
    tags: ["silent", "horror"],
    popularity: 66
  },
  {
    id: "SafetyLastHaroldLloyd1923.FullMovieexcellentQuality.",
    title: "Safety Last!",
    year: 1923,
    genres: ["Comedy", "Silent"],
    rating: 8.1,
    runtimeMinutes: 73,
    blurb:
      "A small-town boy pretends to be a big-city success and ends up climbing a skyscraper for real. Harold Lloyd's clock-face stunt is one of cinema's great set pieces.",
    tags: ["silent", "comedy"],
    popularity: 64
  },
  {
    id: "meet_john_doe",
    title: "Meet John Doe",
    year: 1941,
    genres: ["Drama", "Romance"],
    rating: 7.6,
    runtimeMinutes: 123,
    blurb:
      "A reporter invents a everyman who threatens to jump off City Hall on Christmas Eve, then hires a drifter to play him. Frank Capra's populist fable turns media hype into a movement.",
    tags: ["essential", "drama"],
    popularity: 62
  },
  {
    id: "TheFrontPage1931AdolpheMenjouPatOBrienLewismiles",
    title: "The Front Page",
    year: 1931,
    genres: ["Comedy", "Drama"],
    rating: 7.6,
    runtimeMinutes: 100,
    blurb:
      "A crusading reporter tries to quit on the eve of an execution, but his editor has other plans. The fast-talking newspaper comedy that later became His Girl Friday.",
    tags: ["comedy"],
    popularity: 60
  },
  {
    id: "NothingSacred",
    title: "Nothing Sacred",
    year: 1937,
    genres: ["Comedy", "Romance"],
    rating: 7.2,
    runtimeMinutes: 77,
    blurb:
      "A newspaperman turns a small-town woman's supposed radium poisoning into a national story. A Technicolor screwball satire of tabloid fame.",
    tags: ["comedy"],
    popularity: 58
  },
  {
    id: "TheScarletPimpernel",
    title: "The Scarlet Pimpernel",
    year: 1934,
    genres: ["Adventure", "Drama"],
    rating: 7.4,
    runtimeMinutes: 97,
    blurb:
      "A foppish English aristocrat secretly runs a network smuggling French nobles out of the Revolution. Swashbuckling, disguise, and a very sharp blade.",
    tags: ["adventure"],
    popularity: 56
  },
  {
    id: "humanbondage",
    title: "Of Human Bondage",
    year: 1934,
    genres: ["Drama", "Romance"],
    rating: 7.4,
    runtimeMinutes: 83,
    blurb:
      "A medical student's obsessive affair with a waitress derails his life. Bette Davis gives a ferocious performance in this adaptation of W. Somerset Maugham's novel.",
    tags: ["drama"],
    popularity: 54
  },
  {
    id: "white_zombie",
    title: "White Zombie",
    year: 1932,
    genres: ["Horror"],
    rating: 6.9,
    runtimeMinutes: 69,
    blurb:
      "A Haitian plantation owner turns to a voodoo master to steal the woman he loves. Bela Lugosi presides over an early zombie feature full of atmosphere and dread.",
    tags: ["horror"],
    popularity: 52
  },
  {
    id: "Devil_Bat_movie",
    title: "The Devil Bat",
    year: 1940,
    genres: ["Horror", "Mystery"],
    rating: 6.4,
    runtimeMinutes: 68,
    blurb:
      "A chemist breeds giant bats and uses them to punish the business partners he blames for his failures. Bela Lugosi makes the most of a wonderfully absurd premise.",
    tags: ["horror"],
    popularity: 50
  },
  {
    id: "BeatTheDevil1953",
    title: "Beat the Devil",
    year: 1953,
    genres: ["Comedy", "Adventure"],
    rating: 6.5,
    runtimeMinutes: 89,
    blurb:
      "A group of con artists, dreamers, and opportunists converge on East Africa in pursuit of uranium. Humphrey Bogart and Jennifer Jones in a wry, shaggy caper.",
    tags: ["comedy", "adventure"],
    popularity: 48
  },
  {
    id: "suddenly",
    title: "Suddenly",
    year: 1954,
    genres: ["Film Noir", "Thriller"],
    rating: 6.8,
    runtimeMinutes: 75,
    blurb:
      "Three gunmen take over a California home to prepare a shot at the President. Frank Sinatra plays the cold-eyed leader in a compact, tense siege thriller.",
    tags: ["noir"],
    popularity: 46
  },
  {
    id: "plan-9-from-outer-space_202009",
    title: "Plan 9 from Outer Space",
    year: 1959,
    genres: ["Sci-Fi", "Horror"],
    rating: 4.0,
    runtimeMinutes: 79,
    blurb:
      "Aliens resurrect the dead to stop humanity from destroying the universe. Ed Wood's gloriously ramshackle cult classic is best enjoyed with friends and low expectations.",
    tags: ["scifi", "horror", "cult"],
    popularity: 44
  },
  {
    id: "reefer_madness1938",
    title: "Reefer Madness",
    year: 1938,
    genres: ["Drama"],
    rating: 5.0,
    runtimeMinutes: 68,
    blurb:
      "A lurid cautionary tale about a group of teenagers led astray. The film's overheated warnings turned it into a midnight-movie comedy decades later.",
    tags: ["cult", "drama"],
    popularity: 42
  },
  {
    id: "the-last-man-on-earth-1964-by-ubaldo-ragona-and-sidney-salkow",
    title: "The Last Man on Earth",
    year: 1964,
    genres: ["Sci-Fi", "Horror"],
    rating: 6.9,
    runtimeMinutes: 86,
    blurb:
      "A plague has turned most of humanity into nocturnal creatures, and one survivor spends his days clearing the city. Vincent Price anchors the first adaptation of I Am Legend.",
    tags: ["scifi", "horror"],
    popularity: 40
  },
  {
    id: "TeenagersFromOuterSpace",
    title: "Teenagers from Outer Space",
    year: 1959,
    genres: ["Sci-Fi", "Horror"],
    rating: 4.5,
    runtimeMinutes: 86,
    blurb:
      "An alien scout goes rogue when he learns his people plan to use Earth as a pasture. A shoestring sci-fi curiosity with a memorable giant-shadow effect.",
    tags: ["scifi"],
    popularity: 38
  },
  {
    id: "TheWaspWoman1959",
    title: "The Wasp Woman",
    year: 1959,
    genres: ["Sci-Fi", "Horror"],
    rating: 5.3,
    runtimeMinutes: 73,
    blurb:
      "A cosmetics executive tests an experimental serum on herself and starts turning into something predatory. Roger Corman's beauty-industry creature feature.",
    tags: ["scifi", "horror"],
    popularity: 36
  },
  {
    id: "TheGiantGilaMonster",
    title: "The Giant Gila Monster",
    year: 1959,
    genres: ["Sci-Fi", "Horror"],
    rating: 4.3,
    runtimeMinutes: 74,
    blurb:
      "A small Texas town is terrorized by a lizard the size of a barn. Drive-in creature-feature charm, hot rods, and a lot of miniature work.",
    tags: ["scifi"],
    popularity: 34
  },
  {
    id: "TheKillerShrews",
    title: "The Killer Shrews",
    year: 1959,
    genres: ["Sci-Fi", "Horror"],
    rating: 4.9,
    runtimeMinutes: 69,
    blurb:
      "Storm-bound researchers on an island discover that their experiment has produced oversized, venomous shrews. A beloved low-budget siege movie with dogs in fuzzy costumes.",
    tags: ["scifi"],
    popularity: 32
  },
  {
    id: "the-brain-that-wouldnt-die-custom-movie",
    title: "The Brain That Wouldn't Die",
    year: 1962,
    genres: ["Horror", "Sci-Fi"],
    rating: 5.4,
    runtimeMinutes: 82,
    blurb:
      "A surgeon keeps his fiancée's severed head alive while searching for a new body. Gleefully lurid mad-scientist horror with a surprisingly sharp tongue.",
    tags: ["horror", "scifi"],
    popularity: 30
  },
  {
    id: "TheTerror1963",
    title: "The Terror",
    year: 1963,
    genres: ["Horror", "Mystery"],
    rating: 5.1,
    runtimeMinutes: 79,
    blurb:
      "A lost French officer follows a mysterious woman to a crumbling castle and its haunted baron. A foggy, dreamlike curiosity from Roger Corman's rapid-fire Poe cycle.",
    tags: ["horror"],
    popularity: 28
  },
  {
    id: "TheSnowCreature",
    title: "The Snow Creature",
    year: 1954,
    genres: ["Sci-Fi", "Horror"],
    rating: 4.4,
    runtimeMinutes: 71,
    blurb:
      "A Himalayan expedition captures a yeti and ships it to Los Angeles. A chilly creature feature that gets weirder with every reel.",
    tags: ["scifi"],
    popularity: 26
  },
  {
    id: "gullivers_travels1939",
    title: "Gulliver's Travels",
    year: 1939,
    genres: ["Family", "Animation", "Adventure"],
    rating: 6.6,
    runtimeMinutes: 76,
    blurb:
      "A shipwrecked explorer washes ashore in a kingdom of tiny people. The Fleischer studio's hand-drawn answer to Snow White is a colorful family adventure.",
    tags: ["family", "animation"],
    popularity: 60
  },
  {
    id: "All.Quiet.on.the.Western.Front.1930_201605",
    title: "All Quiet on the Western Front",
    year: 1930,
    genres: ["War", "Drama"],
    rating: 8.1,
    runtimeMinutes: 152,
    blurb:
      "A group of German schoolboys enlist in World War I and discover the gap between patriotic speeches and the trenches. Lewis Milestone's sweeping, humane anti-war epic.",
    tags: ["essential", "drama", "war"],
    popularity: 70
  },
  {
    id: "BattleshipPotemkin",
    title: "Battleship Potemkin",
    year: 1925,
    genres: ["Drama", "Silent", "War"],
    rating: 7.9,
    runtimeMinutes: 75,
    blurb:
      "Sailors revolt after being served rotting meat, and the uprising spreads to the city. Sergei Eisenstein's montage masterpiece, including the Odessa Steps sequence.",
    tags: ["silent", "drama"],
    popularity: 55
  },
  {
    id: "ATripToTheMoon1902",
    title: "A Trip to the Moon",
    year: 1902,
    genres: ["Sci-Fi", "Silent", "Short"],
    rating: 8.1,
    runtimeMinutes: 13,
    blurb:
      "A band of astronomers launches themselves to the moon and meets its strange inhabitants. Georges Méliès turned stage magic into cinema's first great science-fiction spectacle.",
    tags: ["silent", "scifi", "short"],
    popularity: 50
  },
  {
    id: "peter-lorre-in-alfred-hitchcocks-1934-the-man-who-knew-too-much-..-a-special-favourite",
    title: "The Man Who Knew Too Much",
    year: 1934,
    genres: ["Thriller", "Mystery"],
    rating: 7.6,
    runtimeMinutes: 75,
    blurb:
      "A holidaying couple stumble onto an assassination plot and must stop it without endangering their kidnapped child. Early Hitchcock, already playing the audience like a piano.",
    tags: ["essential"],
    popularity: 65
  }
];
