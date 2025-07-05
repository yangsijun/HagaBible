//
//  MockDataBase.swift
//  HagaBible
//
//  Created by 양시준 on 7/5/25.
//


struct MockDataBase {
    static let shared = MockDataBase()
    
    var bibleVersions: [BibleVersion] = [
        BibleVersion(
            id: "WEBBE",
            language: "en_GB",
            name: "World English Bible British Edition",
            isDownloaded: true
        ),
        BibleVersion(
            id: "NKRV",
            language: "ko_KR",
            name: "개역개정",
            isDownloaded: false
        )
    ]
    
    var bibleContents: [BibleContent] = [
        BibleContent(id: "GEN_WEBBE", version: "WEBBE", books: [
            Book(id: "GEN_WEBBE", book: "GEN", bookOrder: 1, bookName: "Genesis", version: "WEBBE", totalChapters: 50, chapters: [
                Chapter(id: "GEN1_WEBBE", book: "GEN", chapter: 1, version: "WEBBE", totalVerses: 31, verses: [
                    Verse(id: "GN1_1_WEBBE", canonOrder: "002_001_001", book: "GEN", chapter: 1, verse: 1, version: "WEBBE", text: "In the beginning, God created the heavens and the earth."),
                    Verse(id: "GN1_2_WEBBE", canonOrder: "002_001_002", book: "GEN", chapter: 1, verse: 2, version: "WEBBE", text: "The earth was formless and empty. Darkness was on the surface of the deep and God’s Spirit was hovering over the surface of the waters."),
                    Verse(id: "GN1_3_WEBBE", canonOrder: "002_001_003", book: "GEN", chapter: 1, verse: 3, version: "WEBBE", text: "God said, “Let there be light,” and there was light."),
                    Verse(id: "GN1_4_WEBBE", canonOrder: "002_001_004", book: "GEN", chapter: 1, verse: 4, version: "WEBBE", text: "God saw the light, and saw that it was good. God divided the light from the darkness."),
                    Verse(id: "GN1_5_WEBBE", canonOrder: "002_001_005", book: "GEN", chapter: 1, verse: 5, version: "WEBBE", text: "God called the light “day”, and the darkness he called “night”. There was evening and there was morning, the first day."),
                    Verse(id: "GN1_6_WEBBE", canonOrder: "002_001_006", book: "GEN", chapter: 1, verse: 6, version: "WEBBE", text: "God said, “Let there be an expanse in the middle of the waters, and let it divide the waters from the waters.”"),
                    Verse(id: "GN1_7_WEBBE", canonOrder: "002_001_007", book: "GEN", chapter: 1, verse: 7, version: "WEBBE", text: "God made the expanse, and divided the waters which were under the expanse from the waters which were above the expanse; and it was so."),
                    Verse(id: "GN1_8_WEBBE", canonOrder: "002_001_008", book: "GEN", chapter: 1, verse: 8, version: "WEBBE", text: "God called the expanse “sky”. There was evening and there was morning, a second day."),
                    Verse(id: "GN1_9_WEBBE", canonOrder: "002_001_009", book: "GEN", chapter: 1, verse: 9, version: "WEBBE", text: "God said, “Let the waters under the sky be gathered together to one place, and let the dry land appear;” and it was so."),
                    Verse(id: "GN1_10_WEBBE", canonOrder: "002_001_010", book: "GEN", chapter: 1, verse: 10, version: "WEBBE", text: "God called the dry land “earth”, and the gathering together of the waters he called “seas”. God saw that it was good."),
                    Verse(id: "GN1_11_WEBBE", canonOrder: "002_001_011", book: "GEN", chapter: 1, verse: 11, version: "WEBBE", text: "God said, “Let the earth yield grass, herbs yielding seeds, and fruit trees bearing fruit after their kind, with their seeds in it, on the earth;” and it was so."),
                    Verse(id: "GN1_12_WEBBE", canonOrder: "002_001_012", book: "GEN", chapter: 1, verse: 12, version: "WEBBE", text: "The earth yielded grass, herbs yielding seed after their kind, and trees bearing fruit, with their seeds in it, after their kind; and God saw that it was good."),
                    Verse(id: "GN1_13_WEBBE", canonOrder: "002_001_013", book: "GEN", chapter: 1, verse: 13, version: "WEBBE", text: "There was evening and there was morning, a third day."),
                    Verse(id: "GN1_14_WEBBE", canonOrder: "002_001_014", book: "GEN", chapter: 1, verse: 14, version: "WEBBE", text: "God said, “Let there be lights in the expanse of the sky to divide the day from the night; and let them be for signs to mark seasons, days, and years;"),
                    Verse(id: "GN1_15_WEBBE", canonOrder: "002_001_015", book: "GEN", chapter: 1, verse: 15, version: "WEBBE", text: "and let them be for lights in the expanse of the sky to give light on the earth;” and it was so."),
                    Verse(id: "GN1_16_WEBBE", canonOrder: "002_001_016", book: "GEN", chapter: 1, verse: 16, version: "WEBBE", text: "God made the two great lights: the greater light to rule the day, and the lesser light to rule the night. He also made the stars."),
                    Verse(id: "GN1_17_WEBBE", canonOrder: "002_001_017", book: "GEN", chapter: 1, verse: 17, version: "WEBBE", text: "God set them in the expanse of the sky to give light to the earth,"),
                    Verse(id: "GN1_18_WEBBE", canonOrder: "002_001_018", book: "GEN", chapter: 1, verse: 18, version: "WEBBE", text: "and to rule over the day and over the night, and to divide the light from the darkness. God saw that it was good."),
                    Verse(id: "GN1_19_WEBBE", canonOrder: "002_001_019", book: "GEN", chapter: 1, verse: 19, version: "WEBBE", text: "There was evening and there was morning, a fourth day."),
                    Verse(id: "GN1_20_WEBBE", canonOrder: "002_001_020", book: "GEN", chapter: 1, verse: 20, version: "WEBBE", text: "God said, “Let the waters abound with living creatures, and let birds fly above the earth in the open expanse of the sky.”"),
                    Verse(id: "GN1_21_WEBBE", canonOrder: "002_001_021", book: "GEN", chapter: 1, verse: 21, version: "WEBBE", text: "God created the large sea creatures and every living creature that moves, with which the waters swarmed, after their kind, and every winged bird after its kind. God saw that it was good."),
                    Verse(id: "GN1_22_WEBBE", canonOrder: "002_001_022", book: "GEN", chapter: 1, verse: 22, version: "WEBBE", text: "God blessed them, saying, “Be fruitful, and multiply, and fill the waters in the seas, and let birds multiply on the earth.”"),
                    Verse(id: "GN1_23_WEBBE", canonOrder: "002_001_023", book: "GEN", chapter: 1, verse: 23, version: "WEBBE", text: "There was evening and there was morning, a fifth day."),
                    Verse(id: "GN1_24_WEBBE", canonOrder: "002_001_024", book: "GEN", chapter: 1, verse: 24, version: "WEBBE", text: "God said, “Let the earth produce living creatures after their kind, livestock, creeping things, and animals of the earth after their kind;” and it was so."),
                    Verse(id: "GN1_25_WEBBE", canonOrder: "002_001_025", book: "GEN", chapter: 1, verse: 25, version: "WEBBE", text: "God made the animals of the earth after their kind, and the livestock after their kind, and everything that creeps on the ground after its kind. God saw that it was good."),
                    Verse(id: "GN1_26_WEBBE", canonOrder: "002_001_026", book: "GEN", chapter: 1, verse: 26, version: "WEBBE", text: "God said, “Let’s make man in our image, after our likeness. Let them have dominion over the fish of the sea, and over the birds of the sky, and over the livestock, and over all the earth, and over every creeping thing that creeps on the earth.”"),
                    Verse(id: "GN1_27_WEBBE", canonOrder: "002_001_027", book: "GEN", chapter: 1, verse: 27, version: "WEBBE", text: "God created man in his own image. In God’s image he created him; male and female he created them."),
                    Verse(id: "GN1_28_WEBBE", canonOrder: "002_001_028", book: "GEN", chapter: 1, verse: 28, version: "WEBBE", text: "God blessed them. God said to them, “Be fruitful, multiply, fill the earth, and subdue it. Have dominion over the fish of the sea, over the birds of the sky, and over every living thing that moves on the earth.”"),
                    Verse(id: "GN1_29_WEBBE", canonOrder: "002_001_029", book: "GEN", chapter: 1, verse: 29, version: "WEBBE", text: "God said, “Behold, I have given you every herb yielding seed, which is on the surface of all the earth, and every tree, which bears fruit yielding seed. It will be your food."),
                    Verse(id: "GN1_30_WEBBE", canonOrder: "002_001_030", book: "GEN", chapter: 1, verse: 30, version: "WEBBE", text: "To every animal of the earth, and to every bird of the sky, and to everything that creeps on the earth, in which there is life, I have given every green herb for food;” and it was so."),
                    Verse(id: "GN1_31_WEBBE", canonOrder: "002_001_031", book: "GEN", chapter: 1, verse: 31, version: "WEBBE", text: "God saw everything that he had made, and, behold, it was very good. There was evening and there was morning, a sixth day."),
                ]),
                Chapter(id: "GEN2_WEBBE", book: "GEN", chapter: 2, version: "WEBBE", totalVerses: 25, verses: [
                    Verse(id: "GN2_1_WEBBE", canonOrder: "002_002_001", book: "GEN", chapter: 2, verse: 1, version: "WEBBE", text: "The heavens, the earth, and all their vast array were finished."),
                    Verse(id: "GN2_2_WEBBE", canonOrder: "002_002_002", book: "GEN", chapter: 2, verse: 2, version: "WEBBE", text: "On the seventh day God finished his work which he had done; and he rested on the seventh day from all his work which he had done."),
                    Verse(id: "GN2_3_WEBBE", canonOrder: "002_002_003", book: "GEN", chapter: 2, verse: 3, version: "WEBBE", text: "God blessed the seventh day, and made it holy, because he rested in it from all his work of creation which he had done."),
                    Verse(id: "GN2_4_WEBBE", canonOrder: "002_002_004", book: "GEN", chapter: 2, verse: 4, version: "WEBBE", text: "This is the history of the generations of the heavens and of the earth when they were created, in the day that the LORD God made the earth and the heavens."),
                    Verse(id: "GN2_5_WEBBE", canonOrder: "002_002_005", book: "GEN", chapter: 2, verse: 5, version: "WEBBE", text: "No plant of the field was yet in the earth, and no herb of the field had yet sprung up; for the LORD God had not caused it to rain on the earth. There was not a man to till the ground,"),
                    Verse(id: "GN2_6_WEBBE", canonOrder: "002_002_006", book: "GEN", chapter: 2, verse: 6, version: "WEBBE", text: "but a mist went up from the earth, and watered the whole surface of the ground."),
                    Verse(id: "GN2_7_WEBBE", canonOrder: "002_002_007", book: "GEN", chapter: 2, verse: 7, version: "WEBBE", text: "The LORD God formed man from the dust of the ground, and breathed into his nostrils the breath of life; and man became a living soul."),
                    Verse(id: "GN2_8_WEBBE", canonOrder: "002_002_008", book: "GEN", chapter: 2, verse: 8, version: "WEBBE", text: "The LORD God planted a garden eastward, in Eden, and there he put the man whom he had formed."),
                    Verse(id: "GN2_9_WEBBE", canonOrder: "002_002_009", book: "GEN", chapter: 2, verse: 9, version: "WEBBE", text: "Out of the ground the LORD God made every tree to grow that is pleasant to the sight, and good for food, including the tree of life in the middle of the garden and the tree of the knowledge of good and evil."),
                    Verse(id: "GN2_10_WEBBE", canonOrder: "002_002_010", book: "GEN", chapter: 2, verse: 10, version: "WEBBE", text: "A river went out of Eden to water the garden; and from there it was parted, and became the source of four rivers."),
                    Verse(id: "GN2_11_WEBBE", canonOrder: "002_002_011", book: "GEN", chapter: 2, verse: 11, version: "WEBBE", text: "The name of the first is Pishon: it flows through the whole land of Havilah, where there is gold;"),
                    Verse(id: "GN2_12_WEBBE", canonOrder: "002_002_012", book: "GEN", chapter: 2, verse: 12, version: "WEBBE", text: "and the gold of that land is good. Bdellium and onyx stone are also there."),
                    Verse(id: "GN2_13_WEBBE", canonOrder: "002_002_013", book: "GEN", chapter: 2, verse: 13, version: "WEBBE", text: "The name of the second river is Gihon. It is the same river that flows through the whole land of Cush."),
                    Verse(id: "GN2_14_WEBBE", canonOrder: "002_002_014", book: "GEN", chapter: 2, verse: 14, version: "WEBBE", text: "The name of the third river is Hiddekel. This is the one which flows in front of Assyria. The fourth river is the Euphrates."),
                    Verse(id: "GN2_15_WEBBE", canonOrder: "002_002_015", book: "GEN", chapter: 2, verse: 15, version: "WEBBE", text: "The LORD God took the man, and put him into the garden of Eden to cultivate and keep it."),
                    Verse(id: "GN2_16_WEBBE", canonOrder: "002_002_016", book: "GEN", chapter: 2, verse: 16, version: "WEBBE", text: "The LORD God commanded the man, saying, “You may freely eat of every tree of the garden;"),
                    Verse(id: "GN2_17_WEBBE", canonOrder: "002_002_017", book: "GEN", chapter: 2, verse: 17, version: "WEBBE", text: "but you shall not eat of the tree of the knowledge of good and evil; for in the day that you eat of it, you will surely die.”"),
                    Verse(id: "GN2_18_WEBBE", canonOrder: "002_002_018", book: "GEN", chapter: 2, verse: 18, version: "WEBBE", text: "The LORD God said, “It is not good for the man to be alone. I will make him a helper comparable to him.”"),
                    Verse(id: "GN2_19_WEBBE", canonOrder: "002_002_019", book: "GEN", chapter: 2, verse: 19, version: "WEBBE", text: "Out of the ground the LORD God formed every animal of the field, and every bird of the sky, and brought them to the man to see what he would call them. Whatever the man called every living creature became its name."),
                    Verse(id: "GN2_20_WEBBE", canonOrder: "002_002_020", book: "GEN", chapter: 2, verse: 20, version: "WEBBE", text: "The man gave names to all livestock, and to the birds of the sky, and to every animal of the field; but for man there was not found a helper comparable to him."),
                    Verse(id: "GN2_21_WEBBE", canonOrder: "002_002_021", book: "GEN", chapter: 2, verse: 21, version: "WEBBE", text: "The LORD God caused the man to fall into a deep sleep. As the man slept, he took one of his ribs, and closed up the flesh in its place."),
                    Verse(id: "GN2_22_WEBBE", canonOrder: "002_002_022", book: "GEN", chapter: 2, verse: 22, version: "WEBBE", text: "The LORD God made a woman from the rib which he had taken from the man, and brought her to the man."),
                    Verse(id: "GN2_23_WEBBE", canonOrder: "002_002_023", book: "GEN", chapter: 2, verse: 23, version: "WEBBE", text: "The man said, “This is now bone of my bones, and flesh of my flesh. She will be called ‘woman,’ because she was taken out of Man.”"),
                    Verse(id: "GN2_24_WEBBE", canonOrder: "002_002_024", book: "GEN", chapter: 2, verse: 24, version: "WEBBE", text: "Therefore a man will leave his father and his mother, and will join with his wife, and they will be one flesh."),
                    Verse(id: "GN2_25_WEBBE", canonOrder: "002_002_025", book: "GEN", chapter: 2, verse: 25, version: "WEBBE", text: "The man and his wife were both naked, and they were not ashamed."),
                ])
            ])
        ])
    ]
}
