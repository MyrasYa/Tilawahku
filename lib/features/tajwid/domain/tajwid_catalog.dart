import 'tajwid_models.dart';

abstract final class TajwidCatalog {
  static const tuhfahReference = TajwidReference(
    title: 'Sulayman al-Jamzuri, Tuḥfat al-Aṭfāl',
    section: 'Nun sukun dan tanwin, mim sukun, ghunnah, serta hukum mad',
    url: 'https://ar.wikisource.org/wiki/تحفة_الأطفال',
  );

  static const jazariyyahReference = TajwidReference(
    title: 'Muhammad ibn al-Jazari, al-Muqaddimah al-Jazariyyah',
    section: 'Makharij, sifat, qalqalah, ra, lam, mad, dan waqaf',
    url: 'https://ar.wikisource.org/wiki/المقدمة_الجزرية',
  );

  static const quranTextReference = TajwidReference(
    title: 'Contoh ayat Al-Qur’an',
    section: 'Teks contoh dimuat dari basis data Al-Qur’an lokal Tilawahku',
    url: 'https://quran.com/',
  );

  static const references = [
    tuhfahReference,
    jazariyyahReference,
    quranTextReference,
  ];

  static const categories = [
    TajwidCategory(
      id: TajwidCategoryId.nunTanwin,
      description:
          'Lima hukum ketika nun sukun atau tanwin bertemu huruf setelahnya.',
    ),
    TajwidCategory(
      id: TajwidCategoryId.mimSukun,
      description: 'Tiga hukum bacaan mim sukun berdasarkan huruf berikutnya.',
    ),
    TajwidCategory(
      id: TajwidCategoryId.mad,
      description:
          'Pengenalan huruf mad, sebab hamzah atau sukun, dan ragam bacaan.',
    ),
    TajwidCategory(
      id: TajwidCategoryId.lam,
      description:
          'Cara membaca lam ta‘rif serta lam pada lafaz Allah dalam konteksnya.',
    ),
    TajwidCategory(
      id: TajwidCategoryId.ra,
      description:
          'Kaidah dasar membaca ra tebal atau tipis; kasus waqaf memiliki rincian.',
    ),
    TajwidCategory(
      id: TajwidCategoryId.qalqalah,
      description: 'Pantulan suara pada huruf qalqalah ketika hurufnya sukun.',
    ),
    TajwidCategory(
      id: TajwidCategoryId.ghunnah,
      description: 'Dengung pada nun dan mim bertasydid.',
    ),
    TajwidCategory(
      id: TajwidCategoryId.makharij,
      description:
          'Pengantar tempat keluarnya huruf untuk membantu membedakan bunyi.',
    ),
    TajwidCategory(
      id: TajwidCategoryId.sifat,
      description:
          'Pengantar sifat pembeda huruf; daftar ini bukan pengganti talaqqi.',
    ),
  ];

  static const lessons = <TajwidLesson>[
    TajwidLesson(
      id: 'izhar-halqi',
      categoryId: TajwidCategoryId.nunTanwin,
      title: 'Izhar Halqi',
      definition:
          'Nun sukun atau tanwin dibaca jelas ketika bertemu salah satu huruf '
          'tenggorokan.',
      condition:
          'Huruf pemicunya ialah ء ه ع ح غ خ. Hukum berlaku pada nun sukun '
          'di dalam kata atau tanwin di akhir kata.',
      readingMethod:
          'Jelaskan bunyi nun atau tanwin pada makhrajnya dan lanjutkan ke '
          'huruf berikutnya tanpa meleburkannya.',
      relatedLetters: 'ء ه ع ح غ خ',
      commonMistake:
          'Meleburkan nun ke huruf berikutnya atau membuat dengung seolah-olah '
          'terjadi idgham.',
      examples: [
        TajwidAyahReference(
          surahNumber: 45,
          ayahNumber: 24,
          note:
              'Perhatikan nun sukun sebelum huruf ‘ain pada lafaz مِنْ عِلْمٍ.',
        ),
      ],
      references: [tuhfahReference, quranTextReference],
    ),
    TajwidLesson(
      id: 'idgham-bighunnah',
      categoryId: TajwidCategoryId.nunTanwin,
      title: 'Idgham Bighunnah',
      definition:
          'Nun sukun atau tanwin dilebur ke huruf sesudahnya disertai ghunnah.',
      condition:
          'Terjadi sebelum ي ن م و (يَنْمُو), biasanya ketika kedua bunyi berada '
          'pada dua kata yang berurutan.',
      readingMethod:
          'Sambungkan bunyi nun atau tanwin ke huruf berikutnya dan pertahankan '
          'ghunnah sesuai talaqqi.',
      relatedLetters: 'ي ن م و',
      commonMistake:
          'Membaca nun dengan jelas seperti izhar atau melebur tanpa ghunnah.',
      examples: [
        TajwidAyahReference(
          surahNumber: 2,
          ayahNumber: 5,
          note: 'Tanwin pada هُدًى bertemu mim pada مِنْ.',
        ),
      ],
      references: [tuhfahReference, quranTextReference],
    ),
    TajwidLesson(
      id: 'idgham-bilaghunnah',
      categoryId: TajwidCategoryId.nunTanwin,
      title: 'Idgham Bilaghunnah',
      definition: 'Nun sukun atau tanwin dilebur ke lam atau ra tanpa ghunnah.',
      condition: 'Huruf pemicunya hanya ل dan ر.',
      readingMethod:
          'Sambungkan bunyi nun atau tanwin ke lam atau ra dengan jelas tanpa '
          'menahan dengung idgham.',
      relatedLetters: 'ل ر',
      commonMistake:
          'Menambahkan ghunnah sehingga tertukar dengan idgham bighunnah.',
      examples: [
        TajwidAyahReference(
          surahNumber: 2,
          ayahNumber: 5,
          note: 'Nun sukun pada مِنْ bertemu ra pada رَبِّهِمْ.',
        ),
      ],
      references: [tuhfahReference, quranTextReference],
    ),
    TajwidLesson(
      id: 'iqlab',
      categoryId: TajwidCategoryId.nunTanwin,
      title: 'Iqlab',
      definition:
          'Bunyi nun sukun atau tanwin diubah menjadi bunyi mim yang samar '
          'ketika bertemu ba.',
      condition: 'Huruf pemicunya satu, yaitu ب.',
      readingMethod:
          'Siapkan bunyi mim dengan ghunnah sebelum melafalkan ba; jangan '
          'mengucapkan nun secara terpisah.',
      relatedLetters: 'ب',
      commonMistake:
          'Melafalkan nun secara jelas atau mengubah bunyi menjadi mim yang '
          'terlalu tegas.',
      examples: [
        TajwidAyahReference(
          surahNumber: 2,
          ayahNumber: 27,
          note: 'Nun sukun pada مِنْ bertemu ba pada بَعْدِ.',
        ),
      ],
      references: [tuhfahReference, quranTextReference],
    ),
    TajwidLesson(
      id: 'ikhfa-haqiqi',
      categoryId: TajwidCategoryId.nunTanwin,
      title: 'Ikhfa Haqiqi',
      definition:
          'Bunyi nun sukun atau tanwin disamarkan di antara izhar dan idgham '
          'ketika bertemu salah satu dari 15 huruf ikhfa.',
      condition:
          'Hurufnya ت ث ج د ذ ز س ش ص ض ط ظ ف ق ك, yaitu huruf selain huruf '
          'izhar, idgham, dan ba.',
      readingMethod:
          'Samarkan bunyi nun atau tanwin dengan ghunnah, lalu arahkan lidah '
          'ke makhraj huruf berikutnya.',
      relatedLetters: 'ت ث ج د ذ ز س ش ص ض ط ظ ف ق ك',
      commonMistake:
          'Mengubahnya menjadi izhar penuh atau meleburkannya sepenuhnya.',
      examples: [
        TajwidAyahReference(
          surahNumber: 113,
          ayahNumber: 2,
          note: 'Nun sukun pada مِنْ bertemu syin pada شَرِّ.',
        ),
      ],
      references: [tuhfahReference, quranTextReference],
    ),
    TajwidLesson(
      id: 'izhar-syafawi',
      categoryId: TajwidCategoryId.mimSukun,
      title: 'Izhar Syafawi',
      definition:
          'Mim sukun dibaca jelas ketika bertemu huruf selain mim dan ba.',
      condition:
          'Berlaku sebelum 26 huruf lainnya. Perhatikan khususnya waw dan fa '
          'agar mim tetap terdengar jelas.',
      readingMethod:
          'Tutup kedua bibir untuk mim dengan wajar, kemudian pindah ke huruf '
          'berikutnya tanpa menyamarkannya.',
      relatedLetters: 'Semua huruf selain م dan ب',
      commonMistake:
          'Menyamarkan mim sebelum waw atau fa sehingga bunyinya menyerupai '
          'ikhfa syafawi.',
      examples: [
        TajwidAyahReference(
          surahNumber: 1,
          ayahNumber: 7,
          note: 'Mim sukun pada عَلَيْهِمْ bertemu ghain pada غَيْرِ.',
        ),
      ],
      references: [tuhfahReference, quranTextReference],
    ),
    TajwidLesson(
      id: 'ikhfa-syafawi',
      categoryId: TajwidCategoryId.mimSukun,
      title: 'Ikhfa Syafawi',
      definition: 'Mim sukun disamarkan dengan ghunnah sebelum huruf ba.',
      condition: 'Huruf pemicunya hanya ب.',
      readingMethod:
          'Rapatkan bibir secara ringan untuk menyiapkan ba sambil menjaga '
          'ghunnah; jangan menutup mim dengan tekanan berlebihan.',
      relatedLetters: 'ب',
      commonMistake:
          'Membaca mim terlalu jelas seperti izhar atau meleburkannya penuh '
          'menjadi ba.',
      examples: [
        TajwidAyahReference(
          surahNumber: 105,
          ayahNumber: 4,
          note: 'Mim pada تَرْمِيهِمْ bertemu ba pada بِحِجَارَةٍ.',
        ),
      ],
      references: [tuhfahReference, quranTextReference],
    ),
    TajwidLesson(
      id: 'idgham-mimi',
      categoryId: TajwidCategoryId.mimSukun,
      title: 'Idgham Mimi / Mitslain',
      definition:
          'Mim sukun dilebur ke mim berharakat setelahnya menjadi satu bunyi '
          'mim bertasydid yang disertai ghunnah.',
      condition: 'Terjadi ketika mim sukun bertemu م.',
      readingMethod:
          'Sambungkan kedua mim, pertahankan ghunnah, dan jangan memisahkan '
          'kedua kata.',
      relatedLetters: 'م',
      commonMistake: 'Melewatkan ghunnah atau memberi jeda di antara dua mim.',
      examples: [
        TajwidAyahReference(
          surahNumber: 2,
          ayahNumber: 29,
          note: 'Mim pada لَكُمْ bertemu mim pada مَا.',
        ),
      ],
      references: [tuhfahReference, quranTextReference],
    ),
    TajwidLesson(
      id: 'mad-thabii',
      categoryId: TajwidCategoryId.mad,
      title: 'Mad Thabi‘i',
      definition:
          'Panjang alami pada alif, waw sukun, atau ya sukun yang memenuhi '
          'syarat huruf mad dan tidak diikuti hamzah atau sukun sebagai sebab '
          'mad far‘i.',
      condition:
          'Alif didahului fathah, waw sukun didahului dammah, dan ya sukun '
          'didahului kasrah.',
      readingMethod:
          'Pertahankan panjang alami huruf mad. Jangan menambah panjang tanpa '
          'sebab bacaan lain.',
      relatedLetters: 'ا و ي',
      commonMistake:
          'Menganggap setiap alif, waw, atau ya sebagai huruf mad tanpa '
          'memeriksa harakat sebelumnya.',
      examples: [
        TajwidAyahReference(
          surahNumber: 2,
          ayahNumber: 5,
          note: 'Alif maqsurah pada عَلَىٰ merupakan contoh huruf mad.',
        ),
      ],
      references: [tuhfahReference, quranTextReference],
    ),
    TajwidLesson(
      id: 'mad-wajib-muttasil',
      categoryId: TajwidCategoryId.mad,
      title: 'Mad Wajib Muttashil',
      definition:
          'Huruf mad bertemu hamzah dalam satu kata; ia termasuk mad far‘i '
          'yang wajib dipanjangkan menurut jalur bacaan.',
      condition: 'Huruf mad dan hamzah berada dalam satu kata yang sama.',
      readingMethod:
          'Panjangkan sesuai riwayat dan jalur talaqqi yang digunakan; jangan '
          'menyamakan hitungan seluruh jenis mad tanpa rujukan guru.',
      relatedLetters: 'ا و ي lalu ء dalam satu kata',
      commonMistake:
          'Menyebutnya munfashil padahal hamzah berada dalam kata yang sama.',
      examples: [
        TajwidAyahReference(
          surahNumber: 2,
          ayahNumber: 87,
          note: 'Perhatikan mad yang bertemu hamzah dalam kata جَاءَكُمْ.',
        ),
      ],
      references: [tuhfahReference, quranTextReference],
    ),
    TajwidLesson(
      id: 'mad-jaiz-munfasil',
      categoryId: TajwidCategoryId.mad,
      title: 'Mad Jaiz Munfashil',
      definition:
          'Huruf mad di akhir kata bertemu hamzah pada awal kata berikutnya.',
      condition:
          'Huruf mad dan hamzah terpisah oleh batas kata; panjangnya mengikuti '
          'riwayat dan jalur bacaan.',
      readingMethod:
          'Jaga kesinambungan bacaan dan ikuti kadar mad yang dipelajari untuk '
          'riwayat yang digunakan.',
      relatedLetters: 'ا و ي pada akhir kata, lalu ء pada kata berikutnya',
      commonMistake:
          'Menerapkan aturan mad muttashil meskipun hamzah berada di kata lain.',
      examples: [
        TajwidAyahReference(
          surahNumber: 2,
          ayahNumber: 21,
          note:
              'Pada يَا أَيُّهَا, mad di akhir kata bertemu hamzah pada kata '
              'berikutnya.',
        ),
      ],
      references: [tuhfahReference, quranTextReference],
    ),
    TajwidLesson(
      id: 'mad-lazim',
      categoryId: TajwidCategoryId.mad,
      title: 'Mad Lazim',
      definition:
          'Huruf mad diikuti sukun asli yang tetap ada ketika washal maupun '
          'waqaf.',
      condition:
          'Mad lazim terbagi menjadi kalimi dan harfi; masing-masing dapat '
          'berupa mukhaffaf atau mutsaqqal. Contoh pada materi ini adalah '
          'mad lazim kalimi mutsaqqal.',
      readingMethod:
          'Pertahankan pemanjangan tetap sebagaimana diajarkan untuk riwayat '
          'bacaan. Perincian kadar dan jenis harfi dipelajari bersama guru.',
      relatedLetters:
          'Huruf mad diikuti sukun asli; contoh: ضّ pada الضَّالِّينَ',
      commonMistake:
          'Mengira sukun akibat berhenti sebagai sukun asli atau menyamakan '
          'semua jenis mad.',
      examples: [
        TajwidAyahReference(
          surahNumber: 1,
          ayahNumber: 7,
          note:
              'Pada الضَّالِّينَ, huruf mad diikuti lam bertasydid dalam satu '
              'kata.',
        ),
      ],
      references: [tuhfahReference, quranTextReference],
    ),
    TajwidLesson(
      id: 'mad-aridh-lissukun',
      categoryId: TajwidCategoryId.mad,
      title: 'Mad ‘Aridh Lissukun',
      definition:
          'Huruf mad diikuti huruf berharakat yang menjadi sukun karena waqaf.',
      condition:
          'Sukun yang menjadi sebab hanya muncul ketika berhenti pada kata itu; '
          'ketika washal, sebab waqaf tersebut tidak ada.',
      readingMethod:
          'Pilih cara pemanjangan yang diajarkan untuk riwayat bacaan dan '
          'pertahankan konsistensinya saat waqaf.',
      relatedLetters:
          'Huruf mad sebelum huruf akhir yang disukunkan saat waqaf',
      commonMistake:
          'Menganggap sukun akhir itu selalu asli, termasuk saat bacaan '
          'disambung.',
      examples: [
        TajwidAyahReference(
          surahNumber: 1,
          ayahNumber: 2,
          note:
              'Jika berhenti pada الْعَالَمِينَ, nun di akhir menjadi sukun '
              'karena waqaf.',
        ),
      ],
      references: [tuhfahReference, quranTextReference],
    ),
    TajwidLesson(
      id: 'mad-badal',
      categoryId: TajwidCategoryId.mad,
      title: 'Mad Badal',
      definition:
          'Hamzah berada sebelum huruf mad dalam satu kata; bentuk hamzah '
          'mendahului huruf mad.',
      condition: 'Contoh bentuknya mencakup hamzah yang diikuti alif mad.',
      readingMethod:
          'Baca hamzah lalu huruf mad sesuai riwayat; jangan mengubah urutan '
          'atau menghilangkan hamzah.',
      relatedLetters: 'ء diikuti ا و ي sebagai huruf mad',
      commonMistake:
          'Menyangka setiap rangkaian hamzah dan mad sebagai mad muttashil; '
          'perhatikan urutannya.',
      examples: [
        TajwidAyahReference(
          surahNumber: 2,
          ayahNumber: 8,
          note: 'Kata آمَنَّا memuat hamzah sebelum huruf mad alif.',
        ),
      ],
      references: [tuhfahReference, quranTextReference],
    ),
    TajwidLesson(
      id: 'mad-lin',
      categoryId: TajwidCategoryId.mad,
      title: 'Mad Lin',
      definition:
          'Waw atau ya sukun didahului fathah; keduanya disebut huruf lin.',
      condition:
          'Contoh pemanjangan lin terjadi saat berhenti sehingga huruf '
          'setelahnya menjadi sukun.',
      readingMethod:
          'Pada waqaf, baca dengan kelembutan dan kadar yang dipelajari untuk '
          'riwayat bacaan. Ketika washal, jangan menerapkan mad waqaf tanpa '
          'sebab.',
      relatedLetters: 'وْ atau يْ yang didahului fathah',
      commonMistake:
          'Mencampuradukkan huruf lin dengan huruf mad atau memanjangkannya '
          'tanpa memperhatikan waqaf.',
      examples: [
        TajwidAyahReference(
          surahNumber: 106,
          ayahNumber: 4,
          note:
              'خَوْفٍ memuat waw sukun yang didahului fathah; perhatikan '
              'ketika waqaf.',
        ),
      ],
      references: [tuhfahReference, quranTextReference],
    ),
    TajwidLesson(
      id: 'mad-iwad',
      categoryId: TajwidCategoryId.mad,
      title: 'Mad ‘Iwad',
      definition:
          'Ketika waqaf pada kata bertanwin fathah, bunyi tanwin diganti '
          'dengan pemanjangan alif sebagai pengganti.',
      condition:
          'Berlaku saat berhenti pada tanwin fathah, dengan pengecualian '
          'bentuk-bentuk akhir kata yang tidak dibaca sebagai alif pengganti, '
          'seperti ta marbuthah.',
      readingMethod:
          'Hentikan bunyi tanwin dan baca alif pengganti sesuai kaidah waqaf; '
          'jangan menerapkannya saat washal.',
      relatedLetters: 'Tanwin fathah pada akhir kata',
      commonMistake:
          'Menerapkan mad ‘iwad saat menyambung bacaan atau pada ta marbuthah.',
      examples: [
        TajwidAyahReference(
          surahNumber: 2,
          ayahNumber: 29,
          note:
              'Jika berhenti pada جَمِيعًا, perhatikan bentuk baca saat '
              'waqaf; lafaz ini berada di tengah ayat.',
        ),
      ],
      references: [jazariyyahReference, quranTextReference],
    ),
    TajwidLesson(
      id: 'mad-silah',
      categoryId: TajwidCategoryId.mad,
      title: 'Mad Shilah',
      definition:
          'Pemanjangan pada ha dhamir tunggal ketika syarat sambungan ha '
          'terpenuhi.',
      condition:
          'Dalam bacaan Hafs yang menjadi contoh materi, ha dhamir berada '
          'di antara huruf berharakat. Jika sesudahnya hamzah, pembahasannya '
          'disebut shilah kubra; jika bukan hamzah, shilah sughra. Perincian '
          'riwayat dapat berbeda.',
      readingMethod:
          'Periksa harakat sebelum dan sesudah ha serta hamzah setelahnya; '
          'jangan menyambungkan ha jika syaratnya tidak terpenuhi atau bacaan '
          'berhenti di sana.',
      relatedLetters: 'هُ atau هِ sebagai ha dhamir',
      commonMistake:
          'Menganggap setiap ha akhir kata sebagai ha dhamir yang mendapat '
          'shilah.',
      examples: [
        TajwidAyahReference(
          surahNumber: 17,
          ayahNumber: 25,
          note:
              'Periksa ha dhamir pada إِنَّهُۥ dalam rangkaian إِنَّهُۥ كَانَ.',
        ),
      ],
      references: [tuhfahReference, jazariyyahReference, quranTextReference],
    ),
    TajwidLesson(
      id: 'mad-tamkin',
      categoryId: TajwidCategoryId.mad,
      title: 'Mad Tamkin',
      definition:
          'Panjang pada ya yang berharakat kasrah dan bertasydid ketika '
          'sesudahnya terdapat ya mad, untuk menjaga kejelasan kedua bunyi.',
      condition:
          'Contoh yang lazim dibahas terdapat pada bentuk seperti النَّبِيِّينَ.',
      readingMethod:
          'Bedakan ya bertasydid dari ya mad setelahnya; ucapkan berurutan '
          'tanpa menghilangkan tasydid atau melebur kedua bunyi secara '
          'berlebihan.',
      relatedLetters: 'يّ diikuti يْ mad',
      commonMistake:
          'Menghilangkan tasydid pada ya pertama atau mengucapkan dua ya '
          'seolah-olah satu huruf.',
      examples: [
        TajwidAyahReference(
          surahNumber: 2,
          ayahNumber: 61,
          note:
              'Bentuk النَّبِيِّينَ digunakan untuk memperhatikan dua ya '
              'yang berurutan.',
        ),
      ],
      references: [jazariyyahReference, quranTextReference],
    ),
    TajwidLesson(
      id: 'lam-qamariyah',
      categoryId: TajwidCategoryId.lam,
      title: 'Lam Ta‘rif Qamariyah',
      definition:
          'Lam pada alif-lam ta‘rif dibaca jelas ketika diikuti huruf qamariyah.',
      condition: 'Huruf qamariyah: ا ب ج ح خ ع غ ف ق ك م ه و ي.',
      readingMethod:
          'Bunyikan lam dengan jelas sebelum huruf qamariyah; jangan '
          'meleburkannya.',
      relatedLetters: 'ا ب ج ح خ ع غ ف ق ك م ه و ي',
      commonMistake:
          'Menghilangkan bunyi lam karena mengira semua alif-lam mengalami '
          'idgham.',
      examples: [
        TajwidAyahReference(
          surahNumber: 91,
          ayahNumber: 2,
          note: 'Lam pada الْقَمَرِ dibaca jelas.',
        ),
      ],
      references: [jazariyyahReference, quranTextReference],
    ),
    TajwidLesson(
      id: 'lam-syamsiyah',
      categoryId: TajwidCategoryId.lam,
      title: 'Lam Ta‘rif Syamsiyah',
      definition:
          'Lam pada alif-lam ta‘rif tidak terdengar karena dilebur ke huruf '
          'syamsiyah yang bertasydid.',
      condition: 'Huruf syamsiyah: ت ث د ذ ر ز س ش ص ض ط ظ ل ن.',
      readingMethod:
          'Baca huruf syamsiyah bertasydid dengan tasydidnya; jangan '
          'menambahkan bunyi lam tersendiri.',
      relatedLetters: 'ت ث د ذ ر ز س ش ص ض ط ظ ل ن',
      commonMistake:
          'Membaca lam dengan jelas atau menghilangkan tasydid pada huruf '
          'syamsiyah.',
      examples: [
        TajwidAyahReference(
          surahNumber: 91,
          ayahNumber: 1,
          note: 'Lam ta‘rif pada الشَّمْسِ melebur ke syin.',
        ),
      ],
      references: [jazariyyahReference, quranTextReference],
    ),
    TajwidLesson(
      id: 'lam-allah',
      categoryId: TajwidCategoryId.lam,
      title: 'Lam pada Lafaz Allah',
      definition:
          'Lam pada lafaz Allah dibaca tebal atau tipis sesuai harakat '
          'sebelumnya.',
      condition:
          'Secara dasar, dibaca tebal setelah fathah atau dammah, dan tipis '
          'setelah kasrah. Kasus sambungan dan waqaf perlu diperiksa pada '
          'konteksnya.',
      readingMethod:
          'Perhatikan harakat tepat sebelum lafaz Allah dalam bacaan sambung; '
          'jika memulai dari lafaz Allah, ikuti kaidah ibtida yang dipelajari.',
      relatedLetters: 'ل pada lafaz الله',
      commonMistake:
          'Membaca lam Allah selalu tebal atau selalu tipis tanpa melihat '
          'harakat sebelumnya.',
      examples: [
        TajwidAyahReference(
          surahNumber: 1,
          ayahNumber: 1,
          note: 'Pada بِسْمِ اللَّهِ, lam Allah didahului kasrah.',
        ),
        TajwidAyahReference(
          surahNumber: 2,
          ayahNumber: 255,
          note: 'Ayat dimulai dengan lafaz اللَّهُ; perhatikan hukum ibtida.',
        ),
      ],
      references: [jazariyyahReference, quranTextReference],
    ),
    TajwidLesson(
      id: 'ra-tafkhim',
      categoryId: TajwidCategoryId.ra,
      title: 'Ra Tafkhim',
      definition: 'Ra dibaca tebal pada kondisi-kondisi yang memenuhi tafkhim.',
      condition:
          'Kaidah dasar: ra berharakat fathah atau dammah, serta ra sukun '
          'yang didahului fathah atau dammah. Waqaf dan keadaan khusus '
          'memiliki rincian.',
      readingMethod:
          'Tebalkan bunyi ra tanpa berlebihan; periksa harakat ra dan huruf '
          'sebelumnya, lalu rujuk guru untuk kasus waqaf.',
      relatedLetters: 'رَ رُ dan رْ setelah fathah atau dammah',
      commonMistake:
          'Menebalkan semua ra tanpa memperhatikan kasrah atau aturan '
          'pengecualian.',
      examples: [
        TajwidAyahReference(
          surahNumber: 1,
          ayahNumber: 2,
          note: 'Ra pada رَبِّ berharakat fathah.',
        ),
      ],
      references: [jazariyyahReference, quranTextReference],
    ),
    TajwidLesson(
      id: 'ra-tarqiq',
      categoryId: TajwidCategoryId.ra,
      title: 'Ra Tarqiq',
      definition: 'Ra dibaca tipis pada kondisi-kondisi yang memenuhi tarqiq.',
      condition:
          'Kaidah dasar: ra berharakat kasrah, atau ra sukun yang didahului '
          'kasrah asli dan tidak diikuti huruf isti‘la dalam kata yang sama. '
          'Sebagian kasus waqaf dan pengecualian memerlukan pembahasan guru.',
      readingMethod:
          'Tipiskan ra tanpa mengubahnya menjadi ya; perhatikan harakat dan '
          'huruf sesudahnya.',
      relatedLetters: 'رِ dan رْ setelah kasrah dengan syaratnya',
      commonMistake:
          'Menipiskan ra sukun setelah kasrah tanpa memeriksa huruf isti‘la '
          'sesudahnya atau sumber kasrah.',
      examples: [
        TajwidAyahReference(
          surahNumber: 2,
          ayahNumber: 49,
          note:
              'Pada فِرْعَوْنَ, ra sukun didahului kasrah asli dan tidak '
              'diikuti huruf isti‘la.',
        ),
      ],
      references: [jazariyyahReference, quranTextReference],
    ),
    TajwidLesson(
      id: 'qalqalah-sughra',
      categoryId: TajwidCategoryId.qalqalah,
      title: 'Qalqalah Sughra',
      definition:
          'Pantulan suara ringan pada salah satu huruf qalqalah yang bersukun '
          'asli di tengah bacaan.',
      condition: 'Huruf qalqalah ialah ق ط ب ج د (قُطْبُ جَدٍّ).',
      readingMethod:
          'Lepaskan pantulan seperlunya pada makhraj huruf; jangan menambahkan '
          'vokal baru.',
      relatedLetters: 'ق ط ب ج د',
      commonMistake:
          'Memberi harakat penuh setelah huruf sukun atau memantulkan huruf '
          'yang tidak termasuk qalqalah.',
      examples: [
        TajwidAyahReference(
          surahNumber: 2,
          ayahNumber: 19,
          note: 'Perhatikan jim sukun pada يَجْعَلُونَ.',
        ),
      ],
      references: [jazariyyahReference, quranTextReference],
    ),
    TajwidLesson(
      id: 'qalqalah-kubra',
      categoryId: TajwidCategoryId.qalqalah,
      title: 'Qalqalah Kubra',
      definition:
          'Pantulan qalqalah yang lebih kuat ketika berhenti pada huruf '
          'qalqalah di akhir kata.',
      condition:
          'Sukun terjadi karena waqaf; jika huruf akhir bertasydid, pantulan '
          'memiliki penekanan tambahan yang dipelajari melalui talaqqi.',
      readingMethod:
          'Hentikan suara pada makhraj huruf dan pantulkan dengan jelas tanpa '
          'menambahkan vokal setelahnya.',
      relatedLetters: 'ق ط ب ج د pada akhir kata saat waqaf',
      commonMistake:
          'Membuat bunyi vokal tambahan setelah huruf atau menyamakan pantulan '
          'waqaf dengan sukun tengah.',
      examples: [
        TajwidAyahReference(
          surahNumber: 113,
          ayahNumber: 1,
          note: 'Jika berhenti pada الْفَلَقِ, qaf menjadi sukun karena waqaf.',
        ),
      ],
      references: [jazariyyahReference, quranTextReference],
    ),
    TajwidLesson(
      id: 'ghunnah-musaddadah',
      categoryId: TajwidCategoryId.ghunnah,
      title: 'Ghunnah Musyaddadah',
      definition:
          'Nun atau mim bertasydid dibaca dengan ghunnah yang keluar melalui '
          'rongga hidung.',
      condition: 'Terjadi pada نّ dan مّ.',
      readingMethod:
          'Pertahankan dengung pada bunyi nun atau mim bertasydid dan jaga '
          'kejelasan makhraj hurufnya.',
      relatedLetters: 'نّ مّ',
      commonMistake:
          'Menghilangkan ghunnah atau mengganti bunyi huruf dengan dengung '
          'tanpa artikulasi nun/mim.',
      examples: [
        TajwidAyahReference(
          surahNumber: 2,
          ayahNumber: 6,
          note: 'Nun bertasydid pada إِنَّ.',
        ),
        TajwidAyahReference(
          surahNumber: 2,
          ayahNumber: 29,
          note: 'Mim bertasydid pada مَّا.',
        ),
      ],
      references: [tuhfahReference, quranTextReference],
    ),
    TajwidLesson(
      id: 'makharij-intro',
      categoryId: TajwidCategoryId.makharij,
      title: 'Pengantar Makharijul Huruf',
      definition:
          'Makharijul huruf adalah tempat keluarnya bunyi huruf ketika '
          'diucapkan.',
      condition:
          'Pembagian umum yang masyhur mencakup rongga mulut, tenggorokan, '
          'lidah, dua bibir, dan rongga hidung. Al-Jazari menyebut 17 makhraj '
          'khusus dalam pembagian yang dipilihnya.',
      readingMethod:
          'Pelajari kelompok tempat keluarnya huruf, lalu dengarkan dan '
          'praktikkan makhraj satu per satu bersama guru.',
      relatedLetters:
          'Rongga: huruf mad; tenggorokan: ء ه ع ح غ خ; bibir: ف ب م و; '
          'rongga hidung: ghunnah.',
      commonMistake:
          'Mengandalkan bentuk tulisan saja; makhraj dan sifat perlu dilatih '
          'dengan suara dan koreksi langsung.',
      examples: [
        TajwidAyahReference(
          surahNumber: 96,
          ayahNumber: 1,
          note:
              'Gunakan ayat ini untuk mengamati beberapa kelompok makhraj; '
              'ayat tidak diberi anotasi makhraj otomatis.',
        ),
      ],
      references: [jazariyyahReference, quranTextReference],
    ),
    TajwidLesson(
      id: 'sifat-huruf-intro',
      categoryId: TajwidCategoryId.sifat,
      title: 'Pengantar Sifat Huruf',
      definition:
          'Sifat huruf menjelaskan karakter bunyi yang menyertai huruf dan '
          'membantu membedakan pelafalannya.',
      condition:
          'Pasangan dasar yang dibahas dalam matan mencakup hams/jahr, '
          'syiddah/rikhwah dengan tawassuth, isti‘la/istifal, '
          'ithbaq/infitah, serta idzlaq/ishmat.',
      readingMethod:
          'Gunakan pasangan sifat untuk membandingkan bunyi huruf. Daftar ini '
          'adalah pengantar, bukan inventaris lengkap seluruh sifat.',
      relatedLetters:
          'Contoh: ف ح ث ه ش خ ص س ك ت untuk hams; أ ج د ق ط ب ك ت untuk '
          'syiddah; خ ص ض غ ط ق ظ untuk isti‘la.',
      commonMistake:
          'Menghafal daftar huruf tanpa melatih bunyi dan tanpa membedakan '
          'sifat yang berlawanan.',
      examples: [
        TajwidAyahReference(
          surahNumber: 96,
          ayahNumber: 1,
          note:
              'Gunakan ayat sebagai bacaan latihan bunyi; aplikasi tidak '
              'menilai sifat pelafalan secara otomatis.',
        ),
      ],
      references: [jazariyyahReference, quranTextReference],
    ),
  ];

  static const questions = <TajwidQuestion>[
    TajwidQuestion(
      id: 'quiz-izhar-letters',
      lessonId: 'izhar-halqi',
      type: TajwidQuestionType.identifyLetters,
      prompt: 'Manakah kelompok huruf izhar halqi?',
      options: ['ء ه ع ح غ خ', 'ي ن م و', 'ل ر', 'ب'],
      correctIndex: 0,
      explanation:
          'Izhar halqi terjadi sebelum enam huruf tenggorokan: ء ه ع ح غ خ.',
    ),
    TajwidQuestion(
      id: 'quiz-idgham-bighunnah',
      lessonId: 'idgham-bighunnah',
      type: TajwidQuestionType.identifyRule,
      prompt: 'Nun sukun atau tanwin bertemu salah satu ي ن م و. Apa hukumnya?',
      options: [
        'Idgham bighunnah',
        'Idgham bilaghunnah',
        'Iqlab',
        'Izhar halqi',
      ],
      correctIndex: 0,
      explanation: 'Empat huruf ي ن م و menjadi pemicu idgham bighunnah.',
    ),
    TajwidQuestion(
      id: 'quiz-idgham-no-ghunnah',
      lessonId: 'idgham-bilaghunnah',
      type: TajwidQuestionType.distinguishRules,
      prompt: 'Huruf apa yang memicu idgham bilaghunnah?',
      options: ['ل dan ر', 'ي dan و', 'م dan ن', 'ب saja'],
      correctIndex: 0,
      explanation:
          'Idgham bilaghunnah terjadi sebelum lam atau ra tanpa ghunnah.',
    ),
    TajwidQuestion(
      id: 'quiz-iqlab',
      lessonId: 'iqlab',
      type: TajwidQuestionType.chooseReading,
      prompt: 'Bagaimana nun sukun atau tanwin dibaca sebelum ب?',
      options: [
        'Diubah menjadi mim samar dengan ghunnah',
        'Dibaca jelas tanpa perubahan',
        'Dilebur tanpa ghunnah',
        'Dipantulkan seperti qalqalah',
      ],
      correctIndex: 0,
      explanation:
          'Iqlab mengubah bunyi nun/tanwin menjadi mim samar dengan ghunnah '
          'sebelum ba.',
    ),
    TajwidQuestion(
      id: 'quiz-ikhfa',
      lessonId: 'ikhfa-haqiqi',
      type: TajwidQuestionType.identifyCategory,
      prompt: 'Nun sukun bertemu ش. Termasuk hukum apa?',
      options: ['Ikhfa haqiqi', 'Izhar halqi', 'Iqlab', 'Idgham bilaghunnah'],
      correctIndex: 0,
      explanation: 'Syin termasuk kelompok 15 huruf ikhfa haqiqi.',
    ),
    TajwidQuestion(
      id: 'quiz-izhar-mim',
      lessonId: 'izhar-syafawi',
      type: TajwidQuestionType.distinguishRules,
      prompt: 'Kapan mim sukun dibaca izhar syafawi?',
      options: [
        'Sebelum huruf selain م dan ب',
        'Hanya sebelum ب',
        'Hanya sebelum م',
        'Sebelum semua huruf dengan peleburan',
      ],
      correctIndex: 0,
      explanation: 'Mim sukun dibaca jelas sebelum huruf selain mim dan ba.',
    ),
    TajwidQuestion(
      id: 'quiz-ikhfa-syafawi',
      lessonId: 'ikhfa-syafawi',
      type: TajwidQuestionType.identifyLetters,
      prompt: 'Apa huruf pemicu ikhfa syafawi?',
      options: ['ب', 'م', 'ل', 'ف'],
      correctIndex: 0,
      explanation: 'Ikhfa syafawi terjadi ketika mim sukun bertemu ba.',
    ),
    TajwidQuestion(
      id: 'quiz-idgham-mimi',
      lessonId: 'idgham-mimi',
      type: TajwidQuestionType.chooseReading,
      prompt: 'Apa yang dilakukan pada mim sukun sebelum mim?',
      options: [
        'Dilebur menjadi mim bertasydid dengan ghunnah',
        'Dibaca jelas tanpa ghunnah',
        'Diubah menjadi ba',
        'Dilebur tanpa ghunnah',
      ],
      correctIndex: 0,
      explanation: 'Mim sukun bertemu mim menjadi idgham mimi dengan ghunnah.',
    ),
    TajwidQuestion(
      id: 'quiz-mad-thabii',
      lessonId: 'mad-thabii',
      type: TajwidQuestionType.identifyRule,
      prompt: 'Apa ciri mad thabi‘i?',
      options: [
        'Huruf mad tanpa sebab hamzah atau sukun setelahnya',
        'Hamzah dan mad dalam satu kata',
        'Sukun asli sesudah huruf mad',
        'Tanwin fathah saat waqaf',
      ],
      correctIndex: 0,
      explanation:
          'Mad thabi‘i adalah panjang alami tanpa sebab mad far‘i berupa '
          'hamzah atau sukun.',
    ),
    TajwidQuestion(
      id: 'quiz-muttasil',
      lessonId: 'mad-wajib-muttasil',
      type: TajwidQuestionType.distinguishRules,
      prompt: 'Apa pembeda utama mad wajib muttashil dari munfashil?',
      options: [
        'Hamzah berada dalam kata yang sama dengan huruf mad',
        'Hamzah berada di awal kata berikutnya',
        'Sebabnya hanya muncul ketika waqaf',
        'Terjadi sebelum huruf ba',
      ],
      correctIndex: 0,
      explanation:
          'Pada muttashil, huruf mad dan hamzah berada di satu kata; pada '
          'munfashil keduanya terpisah oleh batas kata.',
    ),
    TajwidQuestion(
      id: 'quiz-munfasil',
      lessonId: 'mad-jaiz-munfasil',
      type: TajwidQuestionType.identifyRule,
      prompt:
          'Huruf mad berada di akhir kata dan hamzah di awal kata berikutnya. '
          'Apa hukumnya?',
      options: [
        'Mad jaiz munfashil',
        'Mad wajib muttashil',
        'Mad lazim',
        'Mad badal',
      ],
      correctIndex: 0,
      explanation:
          'Mad munfashil memisahkan huruf mad dan hamzah pada dua kata.',
    ),
    TajwidQuestion(
      id: 'quiz-mad-lazim',
      lessonId: 'mad-lazim',
      type: TajwidQuestionType.identifyCategory,
      prompt: 'Apa penyebab mad lazim?',
      options: [
        'Sukun asli setelah huruf mad',
        'Hamzah pada kata berikutnya',
        'Sukun yang hanya muncul karena waqaf',
        'Tanwin fathah di akhir kata',
      ],
      correctIndex: 0,
      explanation:
          'Mad lazim memiliki sukun asli setelah huruf mad dan sebabnya tetap '
          'ada saat washal maupun waqaf.',
    ),
    TajwidQuestion(
      id: 'quiz-mad-aridh',
      lessonId: 'mad-aridh-lissukun',
      type: TajwidQuestionType.distinguishRules,
      prompt: 'Kapan sukun pada mad ‘aridh lissukun muncul?',
      options: [
        'Ketika berhenti pada kata tersebut',
        'Selalu, termasuk ketika washal',
        'Sebelum huruf ba',
        'Ketika hamzah berada dalam satu kata',
      ],
      correctIndex: 0,
      explanation:
          'Sukun pada mad ‘aridh timbul karena waqaf; ketika washal sebab itu '
          'tidak ada.',
    ),
    TajwidQuestion(
      id: 'quiz-mad-badal',
      lessonId: 'mad-badal',
      type: TajwidQuestionType.identifyRule,
      prompt: 'Bagaimana urutan hamzah dan huruf mad pada mad badal?',
      options: [
        'Hamzah sebelum huruf mad',
        'Hamzah setelah huruf mad dalam satu kata',
        'Hamzah pada awal kata berikutnya',
        'Sukun asli sebelum hamzah',
      ],
      correctIndex: 0,
      explanation: 'Mad badal memiliki hamzah sebelum huruf mad.',
    ),
    TajwidQuestion(
      id: 'quiz-mad-lin',
      lessonId: 'mad-lin',
      type: TajwidQuestionType.identifyLetters,
      prompt: 'Huruf apa yang menjadi huruf lin?',
      options: [
        'وْ atau يْ yang didahului fathah',
        'ا yang didahului kasrah',
        'ن sukun sebelum ba',
        'م sukun sebelum mim',
      ],
      correctIndex: 0,
      explanation: 'Huruf lin ialah waw atau ya sukun yang didahului fathah.',
    ),
    TajwidQuestion(
      id: 'quiz-mad-iwad',
      lessonId: 'mad-iwad',
      type: TajwidQuestionType.chooseReading,
      prompt:
          'Apa yang terjadi pada tanwin fathah ketika waqaf dalam mad ‘iwad?',
      options: [
        'Diganti dengan pemanjangan alif pengganti',
        'Dilebur ke huruf berikutnya',
        'Diubah menjadi mim',
        'Dibaca tanwin seperti saat washal',
      ],
      correctIndex: 0,
      explanation:
          'Mad ‘iwad berlaku saat berhenti pada tanwin fathah, dengan '
          'pengecualian bentuk tertentu seperti ta marbuthah.',
    ),
    TajwidQuestion(
      id: 'quiz-mad-silah',
      lessonId: 'mad-silah',
      type: TajwidQuestionType.distinguishRules,
      prompt: 'Kapan ha dhamir dibahas sebagai shilah kubra?',
      options: [
        'Ketika sesudah ha terdapat hamzah dan syarat shilah terpenuhi',
        'Setiap kali ha sukun bertemu ba',
        'Ketika waqaf pada tanwin fathah',
        'Setiap kali ha berada di akhir ayat',
      ],
      correctIndex: 0,
      explanation:
          'Shilah kubra terkait ha dhamir yang memenuhi syarat dan diikuti '
          'hamzah; rincian mengikuti riwayat.',
    ),
    TajwidQuestion(
      id: 'quiz-mad-tamkin',
      lessonId: 'mad-tamkin',
      type: TajwidQuestionType.chooseReading,
      prompt: 'Apa yang dijaga dalam mad tamkin pada ya berurutan?',
      options: [
        'Tasydid ya pertama dan kejelasan ya mad sesudahnya',
        'Peleburan nun ke ra tanpa ghunnah',
        'Pantulan qaf sukun',
        'Lam ta‘rif tetap dibaca jelas',
      ],
      correctIndex: 0,
      explanation:
          'Bacaan memisahkan dengan baik ya bertasydid dan ya mad sesudahnya.',
    ),
    TajwidQuestion(
      id: 'quiz-qamariyah',
      lessonId: 'lam-qamariyah',
      type: TajwidQuestionType.chooseReading,
      prompt: 'Bagaimana lam ta‘rif dibaca sebelum huruf qamariyah?',
      options: [
        'Jelas',
        'Dilebur ke huruf sesudahnya',
        'Diubah menjadi mim',
        'Dihilangkan beserta tasydid huruf sesudahnya',
      ],
      correctIndex: 0,
      explanation: 'Lam ta‘rif qamariyah dibaca jelas.',
    ),
    TajwidQuestion(
      id: 'quiz-syamsiyah',
      lessonId: 'lam-syamsiyah',
      type: TajwidQuestionType.identifyCategory,
      prompt: 'Apa yang terjadi pada lam ta‘rif sebelum huruf syamsiyah?',
      options: [
        'Melebur ke huruf syamsiyah yang bertasydid',
        'Dibaca jelas dan tanpa tasydid',
        'Diubah menjadi nun',
        'Dihentikan dengan qalqalah',
      ],
      correctIndex: 0,
      explanation:
          'Pada lam syamsiyah, lam melebur dan huruf berikutnya dibaca '
          'bertasydid.',
    ),
    TajwidQuestion(
      id: 'quiz-lam-allah',
      lessonId: 'lam-allah',
      type: TajwidQuestionType.distinguishRules,
      prompt: 'Apa yang menentukan tebal atau tipisnya lam pada lafaz Allah?',
      options: [
        'Harakat sebelum lafaz Allah dalam konteks bacaan',
        'Huruf terakhir ayat saja',
        'Jumlah kata dalam ayat',
        'Apakah ayat berada di awal surah',
      ],
      correctIndex: 0,
      explanation:
          'Kaidah dasar memperhatikan harakat sebelum lafaz Allah; konteks '
          'ibtida dan waqaf juga perlu diperiksa.',
    ),
    TajwidQuestion(
      id: 'quiz-ra-tafkhim',
      lessonId: 'ra-tafkhim',
      type: TajwidQuestionType.chooseReading,
      prompt: 'Apa makna tafkhim pada ra?',
      options: [
        'Membaca ra dengan bunyi tebal sesuai kaidah',
        'Membaca ra dengan bunyi tipis',
        'Menyamarkan ra dengan ghunnah',
        'Memantulkan ra pada setiap waqaf',
      ],
      correctIndex: 0,
      explanation:
          'Tafkhim adalah membaca tebal; tetap periksa harakat dan kondisi '
          'pengecualian.',
    ),
    TajwidQuestion(
      id: 'quiz-ra-tarqiq',
      lessonId: 'ra-tarqiq',
      type: TajwidQuestionType.distinguishRules,
      prompt: 'Apa makna tarqiq pada ra?',
      options: [
        'Membaca ra tipis sesuai syaratnya',
        'Membaca ra tebal',
        'Mengubah ra menjadi lam',
        'Menghilangkan ra ketika washal',
      ],
      correctIndex: 0,
      explanation:
          'Tarqiq berarti membaca tipis; kondisi ra sukun dan waqaf memiliki '
          'rincian yang harus dipelajari.',
    ),
    TajwidQuestion(
      id: 'quiz-qalqalah',
      lessonId: 'qalqalah-sughra',
      type: TajwidQuestionType.identifyLetters,
      prompt: 'Manakah lima huruf qalqalah?',
      options: ['ق ط ب ج د', 'ء ه ع ح غ خ', 'ي ن م و', 'ت ث ذ ز س ش'],
      correctIndex: 0,
      explanation: 'Huruf qalqalah diringkas dalam قُطْبُ جَدٍّ.',
    ),
    TajwidQuestion(
      id: 'quiz-qalqalah-kubra',
      lessonId: 'qalqalah-kubra',
      type: TajwidQuestionType.distinguishRules,
      prompt: 'Kapan qalqalah kubra terjadi?',
      options: [
        'Ketika waqaf pada huruf qalqalah di akhir kata',
        'Pada setiap nun sukun sebelum ba',
        'Pada mim sukun sebelum mim',
        'Ketika huruf mad diikuti hamzah dalam satu kata',
      ],
      correctIndex: 0,
      explanation:
          'Pada qalqalah kubra, huruf akhir qalqalah disukunkan karena waqaf.',
    ),
    TajwidQuestion(
      id: 'quiz-ghunnah',
      lessonId: 'ghunnah-musaddadah',
      type: TajwidQuestionType.identifyLetters,
      prompt: 'Huruf apa yang dibaca dengan ghunnah musyaddadah?',
      options: ['نّ dan مّ', 'رّ dan لّ', 'قّ dan طّ', 'بْ dan تْ'],
      correctIndex: 0,
      explanation: 'Ghunnah musyaddadah terdapat pada nun dan mim bertasydid.',
    ),
    TajwidQuestion(
      id: 'quiz-makharij',
      lessonId: 'makharij-intro',
      type: TajwidQuestionType.identifyCategory,
      prompt: 'Manakah kelompok lima makhraj umum yang masyhur?',
      options: [
        'Rongga mulut, tenggorokan, lidah, dua bibir, rongga hidung',
        'Gigi, telinga, tenggorokan, dada, lidah',
        'Hidung, mata, bibir, dada, rahang',
        'Rongga mulut, gigi, bahu, tenggorokan, bibir',
      ],
      correctIndex: 0,
      explanation:
          'Pembagian umum yang masyhur mencakup al-jauf, al-halq, al-lisan, '
          'asy-syafatan, dan al-khaysyum.',
    ),
    TajwidQuestion(
      id: 'quiz-sifat',
      lessonId: 'sifat-huruf-intro',
      type: TajwidQuestionType.identifyCategory,
      prompt: 'Apa tujuan mempelajari sifat huruf?',
      options: [
        'Membedakan karakter bunyi huruf saat dilafalkan',
        'Mengganti teks ayat dengan tanda warna',
        'Menentukan arti ayat tanpa terjemahan',
        'Mengukur kemampuan pelafalan secara otomatis',
      ],
      correctIndex: 0,
      explanation:
          'Sifat menjelaskan karakter bunyi; latihan teks aplikasi tidak '
          'menilai kemampuan pelafalan.',
    ),
  ];
}
