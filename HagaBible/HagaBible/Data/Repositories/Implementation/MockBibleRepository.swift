//
//  BibleRepositoryImpl.swift
//  HagaBible
//
//  Created by 양시준 on 7/5/25.
//

struct MockBibleRepository: BibleRepository {
    static let shared = MockBibleRepository()
    
    private init() {}
    
    private let mockBibleVerses: [BibleVerse] = [
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 1, verseText: "태초에 하나님이 천지를 창조하시니라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 2, verseText: "땅이 혼돈하고 공허하며 흑암이 깊음 위에 있고 하나님의 신은 수면에 운행하시니라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 3, verseText: "하나님이 가라사대 빛이 있으라 하시매 빛이 있었고", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 4, verseText: "그 빛이 하나님의 보시기에 좋았더라 하나님이 빛과 어두움을 나누사", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 5, verseText: "빛을 낮이라 칭하시고 어두움을 밤이라 칭하시니라 저녁이 되며 아침이 되니 이는 첫째 날이니라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 6, verseText: "하나님이 가라사대 물 가운데 궁창이 있어 물과 물로 나뉘게 하리라 하시고", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 7, verseText: "하나님이 궁창을 만드사 궁창 아래의 물과 궁창 위의 물로 나뉘게 하시매 그대로 되니라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 8, verseText: "하나님이 궁창을 하늘이라 칭하시니라 저녁이 되며 아침이 되니 이는 둘째 날이니라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 9, verseText: "하나님이 가라사대 천하의 물이 한곳으로 모이고 뭍이 드러나라 하시매 그대로 되니라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 10, verseText: "하나님이 뭍을 땅이라 칭하시고 모인 물을 바다라 칭하시니라 하나님의 보시기에 좋았더라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 11, verseText: "하나님이 가라사대 땅은 풀과 씨 맺는 채소와 각기 종류대로 씨 가진 열매 맺는 과목을 내라 하시매 그대로 되어", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 12, verseText: "땅이 풀과 각기 종류대로 씨 맺는 채소와 각기 종류대로 씨 가진 열매 맺는 나무를 내니 하나님의 보시기에 좋았더라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 13, verseText: "저녁이 되며 아침이 되니 이는 세째 날이니라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 14, verseText: "하나님이 가라사대 하늘의 궁창에 광명이 있어 주야를 나뉘게 하라 또 그 광명으로 하여 징조와 사시와 일자와 연한이 이루라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 15, verseText: "또 그 광명이 하늘의 궁창에 있어 땅에 비취라 하시고 （그대로 되니라）", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 16, verseText: "하나님이 두 큰 광명을 만드사 큰 광명으로 낮을 주관하게 하시고 작은 광명으로 밤을 주관하게 하시며 또 별들을 만드시고", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 17, verseText: "하나님이 그것들을 하늘의 궁창에 두어 땅에 비취게 하시며", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 18, verseText: "주야를 주관하게 하시며 빛과 어두움을 나뉘게 하시니라 하나님의 보시기에 좋았더라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 19, verseText: "저녁이 되며 아침이 되니 이는 네째 날이니라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 20, verseText: "하나님이 가라사대 물들은 생물로 번성케 하라 땅위 하늘의 궁창에는 새가 날으라 하시고", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 21, verseText: "하나님이 큰 물고기와 물에서 번성하여 움직이는 모든 생물을 그 종류대로, 날개 있는 모든 새를 그 종류대로 창조하시니 하나님의 보시기에 좋았더라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 22, verseText: "하나님이 그들에게 복을 주어 가라사대 생육하고 번성하여 여러 바다 물에 충만하라 새들도 땅에 번성하라 하시니라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 23, verseText: "저녁이 되며 아침이 되니 이는 다섯째 날이니라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 24, verseText: "하나님이 가라사대 땅은 생물을 그 종류대로 내되 육축과 기는 것과 땅의 짐승을 종류대로 내라 하시고 （그대로 되니라）", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 25, verseText: "하나님이 땅의 짐승을 그 종류대로, 육축을 그 종류대로, 땅에 기는 모든 것을 그 종류대로 만드시니 하나님의 보시기에 좋았더라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 26, verseText: "하나님이 가라사대 우리의 형상을 따라 우리의 모양대로 우리가 사람을 만들고 그로 바다의 고기와 공중의 새와 육축과 온 땅과 땅에 기는 모든 것을 다스리게 하자 하시고", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 27, verseText: "하나님이 자기 형상 곧 하나님의 형상대로 사람을 창조하시되 남자와 여자를 창조하시고", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 28, verseText: "하나님이 그들에게 복을 주시며 그들에게 이르시되 생육하고 번성하여 땅에 충만하라, 땅을 정복하라, 바다의 고기와 공중의 새와 땅에 움직이는 모든 생물을 다스리라 하시니라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 29, verseText: "하나님이 가라사대 내가 온 지면의 씨 맺는 모든 채소와 씨 가진 열매 맺는 모든 나무를 너희에게 주노니 너희 식물이 되리라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 30, verseText: "또 땅의 모든 짐승과 공중의 모든 새와 생명이 있어 땅에 기는 모든 것에게는 내가 모든 푸른 풀을 식물로 주노라 하시니 그대로 되니라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 1, verse: 31, verseText: "하나님이 그 지으신 모든 것을 보시니 보시기에 심히 좋았더라 저녁이 되며 아침이 되니 이는 여섯째 날이니라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 2, verse: 1, verseText: "천지와 만물이 다 이루니라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 2, verse: 2, verseText: "하나님의 지으시던 일이 일곱째 날이 이를 때에 마치니 그 지으시던 일이 다하므로 일곱째 날에 안식하시니라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 2, verse: 3, verseText: "하나님이 일곱째 날을 복 주사 거룩하게 하셨으니 이는 하나님이 그 창조하시며 만드시던 모든 일을 마치시고 이 날에 안식하셨음이더라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 2, verse: 4, verseText: "여호와 하나님이 천지를 창조하신 때에 천지의 창조된 대략이 이러하니라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 2, verse: 5, verseText: "여호와 하나님이 땅에 비를 내리지 아니하셨고 경작할 사람도 없었으므로 들에는 초목이 아직 없었고 밭에는 채소가 나지 아니하였으며", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 2, verse: 6, verseText: "안개만 땅에서 올라와 온 지면을 적셨더라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 2, verse: 7, verseText: "여호와 하나님이 흙으로 사람을 지으시고 생기를 그 코에 불어 넣으시니 사람이 생령이 된지라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 2, verse: 8, verseText: "여호와 하나님이 동방의 에덴에 동산을 창설하시고 그 지으신 사람을 거기 두시고", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 2, verse: 9, verseText: "여호와 하나님이 그 땅에서 보기에 아름답고 먹기에 좋은 나무가 나게 하시니 동산 가운데에는 생명나무와 선악을 알게하는 나무도 있더라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 2, verse: 10, verseText: "강이 에덴에서 발원하여 동산을 적시고 거기서부터 갈라져 네 근원이 되었으니", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 2, verse: 11, verseText: "첫째의 이름은 비손이라 금이 있는 하윌라 온 땅에 둘렸으며", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 2, verse: 12, verseText: "그 땅의 금은 정금이요 그곳에는 베델리엄과 호마노도 있으며", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 2, verse: 13, verseText: "둘째 강의 이름은 기혼이라 구스 온 땅에 둘렸고", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 2, verse: 14, verseText: "세째 강의 이름은 힛데겔이라 앗수르 동편으로 흐르며 네째 강은 유브라데더라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 2, verse: 15, verseText: "여호와 하나님이 그 사람을 이끌어 에덴 동산에 두사 그것을 다스리며 지키게 하시고", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 2, verse: 16, verseText: "여호와 하나님이 그 사람에게 명하여 가라사대 동산 각종 나무의 실과는 네가 임의로 먹되", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 2, verse: 17, verseText: "선악을 알게하는 나무의 실과는 먹지 말라 네가 먹는 날에는 정녕 죽으리라 하시니라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 2, verse: 18, verseText: "여호와 하나님이 가라사대 사람의 독처하는 것이 좋지 못하니 내가 그를 위하여 돕는 배필을 지으리라 하시니라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 2, verse: 19, verseText: "여호와 하나님이 흙으로 각종 들짐승과 공중의 각종 새를 지으시고 아담이 어떻게 이름을 짓나 보시려고 그것들을 그에게로 이끌어 이르시니 아담이 각 생물을 일컫는 바가 곧 그 이름이라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 2, verse: 20, verseText: "아담이 모든 육축과 공중의 새와 들의 모든 짐승에게 이름을 주니라 아담이 돕는 배필이 없으므로", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 2, verse: 21, verseText: "여호와 하나님이 아담을 깊이 잠들게 하시니 잠들매 그가 그 갈빗대 하나를 취하고 살로 대신 채우시고", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 2, verse: 22, verseText: "여호와 하나님이 아담에게서 취하신 그 갈빗대로 여자를 만드시고 그를 아담에게로 이끌어 오시니", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 2, verse: 23, verseText: "아담이 가로되 이는 내 뼈 중의 뼈요 살 중의 살이라 이것을 남자에게서 취하였은즉 여자라 칭하리라 하니라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 2, verse: 24, verseText: "이러므로 남자가 부모를 떠나 그 아내와 연합하여 둘이 한 몸을 이룰찌로다", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "창세기", bookOrder: 1, chapter: 2, verse: 25, verseText: "아담과 그 아내 두 사람이 벌거벗었으나 부끄러워 아니하니라", versionCode: "KRV"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 1, verse: 1, verseText: "In the beginning, God created the heavens and the earth.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 1, verse: 2, verseText: "The earth was formless and empty. Darkness was on the surface of the deep and God’s Spirit was hovering over the surface of the waters.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 1, verse: 3, verseText: "God said, “Let there be light,” and there was light.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 1, verse: 4, verseText: "God saw the light, and saw that it was good. God divided the light from the darkness.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 1, verse: 5, verseText: "God called the light “day”, and the darkness he called “night”. There was evening and there was morning, the first day.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 1, verse: 6, verseText: "God said, “Let there be an expanse in the middle of the waters, and let it divide the waters from the waters.”", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 1, verse: 7, verseText: "God made the expanse, and divided the waters which were under the expanse from the waters which were above the expanse; and it was so.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 1, verse: 8, verseText: "God called the expanse “sky”. There was evening and there was morning, a second day.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 1, verse: 9, verseText: "God said, “Let the waters under the sky be gathered together to one place, and let the dry land appear;” and it was so.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 1, verse: 10, verseText: "God called the dry land “earth”, and the gathering together of the waters he called “seas”. God saw that it was good.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 1, verse: 11, verseText: "God said, “Let the earth yield grass, herbs yielding seeds, and fruit trees bearing fruit after their kind, with their seeds in it, on the earth;” and it was so.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 1, verse: 12, verseText: "The earth yielded grass, herbs yielding seed after their kind, and trees bearing fruit, with their seeds in it, after their kind; and God saw that it was good.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 1, verse: 13, verseText: "There was evening and there was morning, a third day.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 1, verse: 14, verseText: "God said, “Let there be lights in the expanse of the sky to divide the day from the night; and let them be for signs to mark seasons, days, and years;", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 1, verse: 15, verseText: "and let them be for lights in the expanse of the sky to give light on the earth;” and it was so.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 1, verse: 16, verseText: "God made the two great lights: the greater light to rule the day, and the lesser light to rule the night. He also made the stars.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 1, verse: 17, verseText: "God set them in the expanse of the sky to give light to the earth,", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 1, verse: 18, verseText: "and to rule over the day and over the night, and to divide the light from the darkness. God saw that it was good.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 1, verse: 19, verseText: "There was evening and there was morning, a fourth day.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 1, verse: 20, verseText: "God said, “Let the waters abound with living creatures, and let birds fly above the earth in the open expanse of the sky.”", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 1, verse: 21, verseText: "God created the large sea creatures and every living creature that moves, with which the waters swarmed, after their kind, and every winged bird after its kind. God saw that it was good.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 1, verse: 22, verseText: "God blessed them, saying, “Be fruitful, and multiply, and fill the waters in the seas, and let birds multiply on the earth.”", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 1, verse: 23, verseText: "There was evening and there was morning, a fifth day.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 1, verse: 24, verseText: "God said, “Let the earth produce living creatures after their kind, livestock, creeping things, and animals of the earth after their kind;” and it was so.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 1, verse: 25, verseText: "God made the animals of the earth after their kind, and the livestock after their kind, and everything that creeps on the ground after its kind. God saw that it was good.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 1, verse: 26, verseText: "God said, “Let’s make man in our image, after our likeness. Let them have dominion over the fish of the sea, and over the birds of the sky, and over the livestock, and over all the earth, and over every creeping thing that creeps on the earth.”", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 1, verse: 27, verseText: "God created man in his own image. In God’s image he created him; male and female he created them.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 1, verse: 28, verseText: "God blessed them. God said to them, “Be fruitful, multiply, fill the earth, and subdue it. Have dominion over the fish of the sea, over the birds of the sky, and over every living thing that moves on the earth.”", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 1, verse: 29, verseText: "God said, “Behold, I have given you every herb yielding seed, which is on the surface of all the earth, and every tree, which bears fruit yielding seed. It will be your food.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 1, verse: 30, verseText: "To every animal of the earth, and to every bird of the sky, and to everything that creeps on the earth, in which there is life, I have given every green herb for food;” and it was so.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 1, verse: 31, verseText: "God saw everything that he had made, and, behold, it was very good. There was evening and there was morning, a sixth day.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 2, verse: 1, verseText: "The heavens, the earth, and all their vast array were finished.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 2, verse: 2, verseText: "On the seventh day God finished his work which he had done; and he rested on the seventh day from all his work which he had done.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 2, verse: 3, verseText: "God blessed the seventh day, and made it holy, because he rested in it from all his work of creation which he had done.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 2, verse: 4, verseText: "This is the history of the generations of the heavens and of the earth when they were created, in the day that the LORD God made the earth and the heavens.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 2, verse: 5, verseText: "No plant of the field was yet in the earth, and no herb of the field had yet sprung up; for the LORD God had not caused it to rain on the earth. There was not a man to till the ground,", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 2, verse: 6, verseText: "but a mist went up from the earth, and watered the whole surface of the ground.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 2, verse: 7, verseText: "The LORD God formed man from the dust of the ground, and breathed into his nostrils the breath of life; and man became a living soul.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 2, verse: 8, verseText: "The LORD God planted a garden eastward, in Eden, and there he put the man whom he had formed.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 2, verse: 9, verseText: "Out of the ground the LORD God made every tree to grow that is pleasant to the sight, and good for food, including the tree of life in the middle of the garden and the tree of the knowledge of good and evil.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 2, verse: 10, verseText: "A river went out of Eden to water the garden; and from there it was parted, and became the source of four rivers.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 2, verse: 11, verseText: "The name of the first is Pishon: it flows through the whole land of Havilah, where there is gold;", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 2, verse: 12, verseText: "and the gold of that land is good. Bdellium and onyx stone are also there.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 2, verse: 13, verseText: "The name of the second river is Gihon. It is the same river that flows through the whole land of Cush.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 2, verse: 14, verseText: "The name of the third river is Hiddekel. This is the one which flows in front of Assyria. The fourth river is the Euphrates.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 2, verse: 15, verseText: "The LORD God took the man, and put him into the garden of Eden to cultivate and keep it.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 2, verse: 16, verseText: "The LORD God commanded the man, saying, “You may freely eat of every tree of the garden;", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 2, verse: 17, verseText: "but you shall not eat of the tree of the knowledge of good and evil; for in the day that you eat of it, you will surely die.”", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 2, verse: 18, verseText: "The LORD God said, “It is not good for the man to be alone. I will make him a helper comparable to him.”", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 2, verse: 19, verseText: "Out of the ground the LORD God formed every animal of the field, and every bird of the sky, and brought them to the man to see what he would call them. Whatever the man called every living creature became its name.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 2, verse: 20, verseText: "The man gave names to all livestock, and to the birds of the sky, and to every animal of the field; but for man there was not found a helper comparable to him.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 2, verse: 21, verseText: "The LORD God caused the man to fall into a deep sleep. As the man slept, he took one of his ribs, and closed up the flesh in its place.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 2, verse: 22, verseText: "The LORD God made a woman from the rib which he had taken from the man, and brought her to the man.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 2, verse: 23, verseText: "The man said, “This is now bone of my bones, and flesh of my flesh. She will be called ‘woman,’ because she was taken out of Man.”", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 2, verse: 24, verseText: "Therefore a man will leave his father and his mother, and will join with his wife, and they will be one flesh.", versionCode: "WEBBE"),
        BibleVerse(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, chapter: 2, verse: 25, verseText: "The man and his wife were both naked, and they were not ashamed.", versionCode: "WEBBE"),
    ]
    
    func fetchBibleVersionList() throws -> [BibleVersion] {
        return [
            BibleVersion(versionCode: "KJV", versionName: "King James Version", language: "English"),
            BibleVersion(versionCode: "WEB", versionName: "World English Bible", language: "English"),
            BibleVersion(versionCode: "WEBBE", versionName: "World English Bible British Edition", language: "English"),
            BibleVersion(versionCode: "KRV", versionName: "개역한글", language: "Korean"),
        ]
    }
    
    func fetchBibleBookList(versionCode: String) throws -> [BibleBook] {
        return [
            BibleBook(bookCode: "GEN", bookName: "창세기", bookOrder: 1, totalChapters: 50, versionCode: "KRV"),
            BibleBook(bookCode: "EXO", bookName: "출애굽기", bookOrder: 2, totalChapters: 40, versionCode: "KRV"),
            BibleBook(bookCode: "LEV", bookName: "레위기", bookOrder: 3, totalChapters: 27, versionCode: "KRV"),
            BibleBook(bookCode: "NUM", bookName: "민수기", bookOrder: 4, totalChapters: 36, versionCode: "KRV"),
            BibleBook(bookCode: "DEU", bookName: "신명기", bookOrder: 5, totalChapters: 34, versionCode: "KRV"),
            BibleBook(bookCode: "GEN", bookName: "Genesis", bookOrder: 1, totalChapters: 50, versionCode: "WEBBE"),
            BibleBook(bookCode: "EXO", bookName: "Exodus", bookOrder: 2, totalChapters: 40, versionCode: "WEBBE"),
            BibleBook(bookCode: "LEV", bookName: "Leviticus", bookOrder: 3, totalChapters: 27, versionCode: "WEBBE"),
            BibleBook(bookCode: "NUM", bookName: "Numbers", bookOrder: 4, totalChapters: 36, versionCode: "WEBBE"),
            BibleBook(bookCode: "DEU", bookName: "Deuteronomy", bookOrder: 5, totalChapters: 34, versionCode: "WEBBE"),
        ].filter { $0.versionCode == versionCode }
    }
    
    func fetchBibleChapterList(versionCode: String, bookCode: String) throws -> [BibleChapter] {
        return [
            BibleChapter(bookCode: "GEN", bookOrder: 1, chapter: 1, totalVerses: 31, versionCode: "KRV"),
            BibleChapter(bookCode: "GEN", bookOrder: 1, chapter: 2, totalVerses: 25, versionCode: "KRV"),
            BibleChapter(bookCode: "GEN", bookOrder: 1, chapter: 3, totalVerses: 24, versionCode: "KRV"),
            BibleChapter(bookCode: "GEN", bookOrder: 1, chapter: 4, totalVerses: 26, versionCode: "KRV"),
            BibleChapter(bookCode: "GEN", bookOrder: 1, chapter: 5, totalVerses: 32, versionCode: "KRV"),
            BibleChapter(bookCode: "EXO", bookOrder: 2, chapter: 1, totalVerses: 22, versionCode: "KRV"),
            BibleChapter(bookCode: "EXO", bookOrder: 2, chapter: 2, totalVerses: 25, versionCode: "KRV"),
            BibleChapter(bookCode: "EXO", bookOrder: 2, chapter: 3, totalVerses: 22, versionCode: "KRV"),
            BibleChapter(bookCode: "EXO", bookOrder: 2, chapter: 4, totalVerses: 31, versionCode: "KRV"),
            BibleChapter(bookCode: "EXO", bookOrder: 2, chapter: 5, totalVerses: 23, versionCode: "KRV"),
            BibleChapter(bookCode: "GEN", bookOrder: 1, chapter: 1, totalVerses: 31, versionCode: "WEBBE"),
            BibleChapter(bookCode: "GEN", bookOrder: 1, chapter: 2, totalVerses: 25, versionCode: "WEBBE"),
            BibleChapter(bookCode: "GEN", bookOrder: 1, chapter: 3, totalVerses: 24, versionCode: "WEBBE"),
            BibleChapter(bookCode: "GEN", bookOrder: 1, chapter: 4, totalVerses: 26, versionCode: "WEBBE"),
            BibleChapter(bookCode: "GEN", bookOrder: 1, chapter: 5, totalVerses: 32, versionCode: "WEBBE"),
            BibleChapter(bookCode: "EXO", bookOrder: 2, chapter: 1, totalVerses: 22, versionCode: "WEBBE"),
            BibleChapter(bookCode: "EXO", bookOrder: 2, chapter: 2, totalVerses: 25, versionCode: "WEBBE"),
            BibleChapter(bookCode: "EXO", bookOrder: 2, chapter: 3, totalVerses: 22, versionCode: "WEBBE"),
            BibleChapter(bookCode: "EXO", bookOrder: 2, chapter: 4, totalVerses: 31, versionCode: "WEBBE"),
            BibleChapter(bookCode: "EXO", bookOrder: 2, chapter: 5, totalVerses: 23, versionCode: "WEBBE"),
        ].filter { $0.versionCode == versionCode && $0.bookCode == bookCode }
    }
    
    func fetchBibleVerseList(versionCode: String, bookCode: String, chapter: Int) throws -> [BibleVerse] {
        return mockBibleVerses.filter { $0.versionCode == versionCode && $0.bookCode == bookCode && $0.chapter == chapter }
    }
    
    func fetchBibleVerse(versionCode: String, bookCode: String, chapter: Int, verse: Int) throws -> BibleVerse? {
        return mockBibleVerses.first(where: {
            $0.versionCode == versionCode
            && $0.bookCode == bookCode
            && $0.chapter == chapter
            && $0.verse == verse
        })
    }
    
    func findByVerseTextContaining(versionCode: String, keyword: String) throws -> [BibleVerse] {
        return mockBibleVerses.filter {
            $0.versionCode == versionCode
            && (($0.verseText?.lowercased().contains(keyword.lowercased())) ?? false)
        }
    }
}
