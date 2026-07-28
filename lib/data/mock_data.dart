import '../models/models.dart';

final mockUEs = <UE>[
  const UE(id: 'ue1', code: 'INF301', title: 'Algorithmique avancée', credits: 6, cm: 20, td: 20, tp: 20, description: 'Structures de données, complexité, algorithmes de graphes.', colorHex: '#0B8F86'),
  const UE(id: 'ue2', code: 'INF302', title: 'Bases de données', credits: 5, cm: 18, td: 18, tp: 24, description: 'Modèle relationnel, SQL, normalisation, transactions.', colorHex: '#2563EB'),
  const UE(id: 'ue3', code: 'INF303', title: 'Développement Mobile', credits: 4, cm: 15, td: 10, tp: 30, description: 'Flutter, Dart, architecture mobile.', colorHex: '#16A34A'),
  const UE(id: 'ue4', code: 'MAT301', title: 'Probabilités', credits: 4, cm: 24, td: 24, tp: 0, description: 'Variables aléatoires, lois usuelles.', colorHex: '#F59E0B'),
  const UE(id: 'ue5', code: 'ANG301', title: 'Anglais technique', credits: 2, cm: 10, td: 20, tp: 0, description: 'Lecture d\'articles techniques et présentations.', colorHex: '#DC2626'),
];

final mockStudents = <Student>[
  const Student(id: 's1', matricule: '21A001', firstName: 'Amina', lastName: 'Diallo', filiere: 'Informatique', niveau: 'L3', status: 'Actif', email: 'amina.diallo@uni.edu', phone: '+221 77 111 22 33', ueIds: ['ue1','ue2','ue3']),
  const Student(id: 's2', matricule: '21A002', firstName: 'Karim', lastName: 'Sow', filiere: 'Informatique', niveau: 'L3', status: 'Actif', email: 'karim.sow@uni.edu', phone: '+221 77 222 33 44', ueIds: ['ue1','ue3','ue4']),
  const Student(id: 's3', matricule: '21A003', firstName: 'Fatou', lastName: 'Ndiaye', filiere: 'Mathématiques', niveau: 'L2', status: 'Suspendu', email: 'fatou.ndiaye@uni.edu', phone: '+221 77 333 44 55', ueIds: ['ue4','ue5']),
  const Student(id: 's4', matricule: '21A004', firstName: 'Moussa', lastName: 'Ba', filiere: 'Informatique', niveau: 'M1', status: 'Actif', email: 'moussa.ba@uni.edu', phone: '+221 77 444 55 66', ueIds: ['ue2','ue3']),
  const Student(id: 's5', matricule: '21A005', firstName: 'Awa', lastName: 'Sarr', filiere: 'Informatique', niveau: 'L3', status: 'Actif', email: 'awa.sarr@uni.edu', phone: '+221 77 555 66 77', ueIds: ['ue1','ue2','ue5']),
];

final mockTeachers = <Teacher>[
  const Teacher(id: 't1', firstName: 'Ibrahima', lastName: 'Fall', status: 'Permanent', email: 'i.fall@uni.edu', department: 'Informatique', ueIds: ['ue1','ue3']),
  const Teacher(id: 't2', firstName: 'Aissatou', lastName: 'Diop', status: 'Permanent', email: 'a.diop@uni.edu', department: 'Informatique', ueIds: ['ue2']),
  const Teacher(id: 't3', firstName: 'Cheikh', lastName: 'Gueye', status: 'Vacataire', email: 'c.gueye@uni.edu', department: 'Mathématiques', ueIds: ['ue4']),
  const Teacher(id: 't4', firstName: 'Marie', lastName: 'Sene', status: 'Vacataire', email: 'm.sene@uni.edu', department: 'Langues', ueIds: ['ue5']),
];

final mockEnrollments = <Enrollment>[
  Enrollment(id: 'e1', studentId: 's1', ueId: 'ue1', status: 'Validée', date: DateTime(2026, 7, 20)),
  Enrollment(id: 'e2', studentId: 's2', ueId: 'ue3', status: 'En attente', date: DateTime(2026, 7, 22)),
  Enrollment(id: 'e3', studentId: 's5', ueId: 'ue2', status: 'En attente', date: DateTime(2026, 7, 23)),
  Enrollment(id: 'e4', studentId: 's4', ueId: 'ue3', status: 'Rejetée', date: DateTime(2026, 7, 18)),
];
