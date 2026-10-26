# DEPLOYMENT SCRIPT

## Deploy
### Contoh Penggunaan:

#### Deploy hari ini:
```bash
./deploy.sh
```

#### Deploy tanggal tertentu:
```bash
./deploy.sh 14042025
```

#### Dry-run untuk hari ini:
```bash
./deploy.sh --dry-run
```

#### Dry-run untuk tanggal tertentu:
```bash
./deploy.sh 14042025 --dry-run
```

## Rollback
### Contoh Penggunaan:

#### Rollback hari ini:
```bash
./rollback.sh
```

#### Rollback tanggal tertentu:
```bash
./rollback.sh 2023.05.12
```

#### Dry-run untuk hari ini:
```bash
./rollback.sh --dry-run
```

#### Dry-run untuk tanggal tertentu:
```bash
./rollback.sh 2023.05.12 --dry-run
```

## Catatan backup dan rollback

- Setiap file yang ditimpa disimpan sebagai `<file>.YYYY.MM.DD` (tanggal deploy). Backup
  lama milik file yang sama (tanggal lain) dihapus; backup file lain tidak disentuh.
- Deploy ulang di hari yang sama tidak menimpa backup hari itu, jadi versi asli sebelum
  deploy tetap tersimpan.
- `chown`/`chmod` hanya untuk file yang di-deploy (beserta backup dan folder induknya),
  bukan seluruh `/apps/helpdesk/` yang juga berisi lampiran.
- `rollback.sh` hanya mengembalikan file yang ditimpa. File baru dari deploy tidak
  dihapus, dan file yang dihapus terpisah (mis. lewat `*-delete.sh`) tidak dikembalikan.
  Untuk rilis besar, simpan juga backup tar folder aplikasi sebelum deploy.
