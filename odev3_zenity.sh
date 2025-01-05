#!/bin/bash

# Gerekli CSV dosyalarını kontrol et ve oluştur
create_csv_files() {
    touch depo.csv kullanici.csv log.csv
    echo "ID,Ad,Stok,BirimFiyat,Kategori" > depo.csv
    echo "ID,KullaniciAdi,Parola,Rol" > kullanici.csv
    echo "HataNo,Tarih,Saat,Kullanici,Ürün,Stok,Fiyat,Hata" > log.csv
}

# Kullanıcı giriş fonksiyonu
user_login() {
    # Giriş ekranı
    login_option=$(zenity --list --title="Giriş Ekranı" --column="İşlemler" \
        "Giriş Yap" \
        "Yeni Kayıt Ol")

    if [ "$login_option" == "Giriş Yap" ]; then
        # Kullanıcı adı ve parola girişi
        user_info=$(zenity --forms --title="Kullanıcı Girişi" \
            --add-entry="Kullanıcı Adı" \
            --add-password="Parola")
       
        if [ -z "$user_info" ]; then
            zenity --error --text="Lütfen kullanıcı adı ve parolanızı girin!"
            return 1
        fi

        IFS="|" read -r username password <<< "$user_info"
       
        # Kullanıcıyı doğrula
        user_record=$(grep -i "$username" kullanici.csv)
       
        if [ -z "$user_record" ]; then
            zenity --error --text="Kullanıcı bulunamadı!"
            log_error "Kullanıcı bulunamadı" "$username" "" ""
            return 1
        fi

        stored_password=$(echo $user_record | cut -d"," -f3)
       
        if [ "$stored_password" != "$password" ]; then
            zenity --error --text="Parola hatalı!"
            log_error "Hatalı parola" "$username" "" ""
            return 1
        fi

        user_role=$(echo $user_record | cut -d"," -f4)
       
        if [ "$user_role" == "Yönetici" ]; then
            main_menu "Yönetici"
        else
            main_menu "Kullanıcı"
        fi
    elif [ "$login_option" == "Yeni Kayıt Ol" ]; then
        register_new_user
    else
        zenity --error --text="Geçersiz işlem seçimi!"
    fi
}

# Yeni kullanıcı kaydı oluşturma
register_new_user() {
    # Kullanıcı adı ve parola girişi
    user_info=$(zenity --forms --title="Yeni Kayıt" \
        --add-entry="Kullanıcı Adı" \
        --add-password="Parola")

    if [ -z "$user_info" ]; then
        zenity --error --text="Kullanıcı adı ve parola boş olamaz!"
        return 1
    fi

    IFS="|" read -r username password <<< "$user_info"

    # Rol seçim ekranı
    role=$(zenity --list --title="Rol Seçimi" --column="Rol" \
        "Yönetici" \
        "Kullanıcı" \
        --width=300 --height=200)

    if [ -z "$role" ]; then
        zenity --error --text="Rol seçimi yapılmalıdır!"
        return 1
    fi

    # Kullanıcı adı kontrolü
    if grep -qi "$username" kullanici.csv; then
        zenity --error --text="Bu kullanıcı adı zaten kayıtlı!"
        return 1
    fi

    # Yeni kullanıcı ID'si
    id=$(($(tail -n 1 kullanici.csv | cut -d"," -f1) + 1))
   
    # Kullanıcıyı ekle
    echo "$id,$username,$password,$role" >> kullanici.csv
    zenity --info --text="Yeni kullanıcı kaydı başarıyla oluşturuldu!"
   
    # Kayıt işleminin ardından, kullanıcıyı menüye yönlendir
    main_menu "$role"
}

# Hata kaydı oluşturma
log_error() {
    local error_message=$1
    local product_name=$2
    local product_stock=$3
    local product_price=$4

    # Hata numarasını belirle (son hata numarasını al, yoksa 1 olarak başla)
    local last_error_no=$(tail -n 1 log.csv | cut -d"," -f1)
    local error_no=1
    if [[ -n "$last_error_no" ]]; then
        error_no=$((last_error_no + 1))
    fi

    # Zaman bilgisi
    local current_date=$(date +%Y-%m-%d)
    local current_time=$(date +%H:%M:%S)

    # Hata kaydını log dosyasına ekle
    echo "$error_no,$current_date,$current_time,$USER,$product_name,$product_stock,$product_price,$error_message" >> log.csv
}

# Ana Menü
main_menu() {
    role=$1

    while true; do
        if [ "$role" == "Yönetici" ]; then
            action=$(zenity --list --title="Yönetici Menü" --column="İşlemler" \
                "Ürün Ekle" \
                "Ürün Güncelle" \
                 "Ürün Listele" \
                "Ürün Sil" \
                "Kullanıcı Yönetimi" \
                "Rapor Al" \
                "Program Yönetimi" \
                "Çıkış")
        else
            action=$(zenity --list --title="Kullanıcı Menü" --column="İşlemler" \
                "Ürünleri Görüntüle" \
                "Ürün Listele" \
                "Rapor Al" \
               
                "Çıkış")
        fi

        case $action in
            "Ürün Ekle")
                add_product
                ;;
            "Ürün Listele")
                urun_listelemek
                ;;
            "Ürün Güncelle")
                update_product
                ;;
            "Ürün Sil")
                delete_product
                ;;
            "Kullanıcı Yönetimi")
                manage_users
                ;;
            "Rapor Al")
                report_option=$(zenity --list --title="Rapor Al" --column="Rapor Seçimi" \
                    "Stokta Azalan Ürünler" \
                    "En Yüksek Stok Miktarına Sahip Ürünler")
                case $report_option in
                    "Stokta Azalan Ürünler")
                        stock_warning_report
                        ;;
                    "En Yüksek Stok Miktarına Sahip Ürünler")
                        high_stock_report
                        ;;
                esac
                ;;
            "Program Yönetimi")
                program_option=$(zenity --list --title="Program Yönetimi" --column="İşlemler" \
                    "Diskteki Alanı Göster" \
                    "Diske Yedekle" \
                    "Hata Kayıtlarını Göster")
                case $program_option in
                    "Diskteki Alanı Göster")
                        show_disk_usage
                        ;;
                    "Diske Yedekle")
                        backup_to_disk
                        ;;
                    "Hata Kayıtlarını Göster")
                        show_error_logs
                        ;;
                esac
                ;;
            "Çıkış")
                exit_program
                ;;
            *)
                zenity --error --text="Geçersiz işlem seçimi!"
                ;;
        esac
    done
}
# Ürün Ekle
# Ürün Ekle
add_product() {
    (
        echo "0"
        echo "# Ürün ekleniyor..."
        sleep 2
       
        input=$(zenity --forms --title="Ürün Ekle" \
            --add-entry="Ürün Adı" \
            --add-entry="Stok Miktarı" \
            --add-entry="Birim Fiyatı" \
            --add-entry="Kategori")

        if [ -z "$input" ]; then
            zenity --error --text="Girdi boş olamaz!"
            log_error "Boş giriş!" "" "" ""
            return
        fi

        IFS="|" read -r name stock price category <<< "$input"

        # Aynı isimde ürün kontrolü
        if grep -qi "^.,$name,.$" depo.csv; then
            # Hata mesajı ve log kaydı
            error_message="Bu ürün adıyla başka bir kayıt bulunmaktadır. Lütfen farklı bir ad giriniz."
            zenity --error --text="$error_message"
            log_error "$error_message" "$name" "$stock" "$price"
            return
        fi

        if ! [[ $stock =~ ^[0-9]+$ && $price =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            zenity --error --text="Stok ve fiyat pozitif sayı olmalıdır!"
            log_error "Geçersiz stok veya fiyat" "$name" "$stock" "$price"
            return
        fi

        # depo.csv oluşturulmamışsa ilk satırı ekle
        if [[ ! -f depo.csv ]]; then
            echo "ID,Ürün Adı,Stok Miktarı,Birim Fiyatı,Kategori" > depo.csv
        fi

        # Son ID'yi al ve bir artır
        last_id=$(tail -n +2 depo.csv | tail -n 1 | cut -d"," -f1)
        if [[ -z "$last_id" || ! "$last_id" =~ ^[0-9]+$ ]]; then
            id=1
        else
            id=$((last_id + 1))
        fi

        # Yeni ürünü dosyaya ekle
        echo "$id,$name,$stock,$price,$category" >> depo.csv

        zenity --info --text="Ürün başarıyla eklendi!"
        echo "100"
    ) | zenity --progress --title="İşlem Yürütülüyor" --text="Ürün ekleniyor..." --percentage=0
}
# Ürün Listeleme
view_products() {
    if [[ ! -s depo.csv ]]; then
        zenity --error --text="Depo boş! Listelenecek ürün bulunmamaktadır."
        return
    fi

    zenity --text-info --title="Ürün Listesi" --filename=depo.csv --width=600 --height=400
}
# Ürün Listele
urun_listelemek() {
    zenity --text-info --filename=depo.csv --title="Ürün Listesi"
}
# Ürün Güncelle
# Ürün Güncelle
update_product() {
    product_name=$(zenity --entry --title="Ürün Güncelle" --text="Güncellemek istediğiniz ürün adını girin:")
    if [[ -z "$product_name" ]]; then
        zenity --error --text="Ürün adı boş olamaz!"
        return
    fi

    product_line=$(grep -i "$product_name" depo.csv)
    if [[ -z "$product_line" ]]; then
        zenity --error --text="Bu ürün bulunamadı!"
        return
    fi

    # Mevcut ürün bilgilerini ayır
    IFS="," read -r id name price stock category <<< "$product_line"

    # Kullanıcıdan güncellenmiş bilgileri al
    updated_info=$(zenity --forms --title="Ürün Güncelle" \
        --add-entry="Ürün Adı" --add-entry="Ürün Fiyatı" --add-entry="Ürün Stok Miktarı" --add-entry="Kategori" \
        --text="Mevcut Bilgiler: $name, $price, $stock, $category")

    if [[ -z "$updated_info" ]]; then
        zenity --error --text="Güncelleme işlemi iptal edildi!"
        return
    fi

    # Güncellenmiş bilgileri ayır
    IFS="|" read -r new_name new_price new_stock new_category <<< "$updated_info"

    # Kategori güncellenebilir olduğu için burada yeni kategori kontrolü yapılır
    sed -i "s/^$id,$name,$price,$stock,$category\$/$id,$new_name,$new_price,$new_stock,$new_category/" depo.csv

    zenity --info --text="Ürün başarıyla güncellendi!"
}

# Ürün Sil
delete_product() {
    product_name=$(zenity --entry --title="Ürün Sil" --text="Silmek istediğiniz ürün adını girin:")
    if [[ -z "$product_name" ]]; then
        zenity --error --text="Ürün adı boş olamaz!"
        return
    fi

    if ! grep -qi "$product_name" depo.csv; then
        zenity --error --text="Bu ürün bulunamadı!"
        return
    fi

    sed -i "/^.*,$product_name,/d" depo.csv
    zenity --info --text="Ürün başarıyla silindi!"
}
# Rapor Al - Stokta Azalan Ürünler
# Rapor Al - Stokta Azalan Ürünler
# Rapor Al - Stokta Azalan Ürünler
stock_warning_report() {
    threshold=$(zenity --entry --title="Stokta Azalan Ürünler" --text="Stok Eşik Değerini Girin:")
   
    # Kullanıcının geçerli bir eşik değeri girmesini kontrol et
    if [[ -z "$threshold" || ! "$threshold" =~ ^[0-9]+$ ]]; then
        zenity --error --text="Geçersiz eşik değeri!"
        return
    fi

    # Stok azalan ürünleri filtrele ve listele (Stok eşik değerinden küçük olan ürünleri listele)
    products=$(awk -F',' -v threshold="$threshold" '$3 < threshold {print $1 " | Fiyat: " $4 " | Stok: " $3}' depo.csv)

    # Ürün bulunup bulunmadığını kontrol et
    if [[ -z "$products" ]]; then
        zenity --info --text="Stokta azalan ürün bulunmamaktadır."
    else
        zenity --text-info --title="Stokta Azalan Ürünler" --text="$products" --width=600 --height=400
    fi
}


# Rapor Al - En Yüksek Stok Miktarına Sahip Ürünler
high_stock_report() {
    threshold=$(zenity --entry --title="En Yüksek Stok Miktarına Sahip Ürünler" --text="Stok Eşik Değerini Girin:")
    if [[ -z "$threshold" || ! "$threshold" =~ ^[0-9]+$ ]]; then
        zenity --error --text="Geçersiz eşik değeri!"
        return
    fi

    # Yüksek stoklu ürünleri filtrele ve listele (Stok eşik değerinden büyük olan ürünleri listele)
    products=$(awk -F',' '$3 > '$threshold' {print $1 " | Fiyat: "$2" | Stok: "$3}' depo.csv)

    if [[ -z "$products" ]]; then
        zenity --info --text="Yüksek stoklu ürün bulunmamaktadır."
    else
        zenity --text-info --title="En Yüksek Stok Miktarına Sahip Ürünler" --text="$products" --width=600 --height=400
    fi
}



# Kullanıcı Yönetimi - Yeni Kullanıcı Ekle
add_user() {
    name=$(zenity --entry --title="Yeni Kullanıcı Ekle" --text="Kullanıcı Adını Girin:")
    username=$(zenity --entry --title="Yeni Kullanıcı Ekle" --text="Kullanıcı Adını (Kullanıcı Adı olarak kullanılacak) Girin:")
    password=$(zenity --entry --title="Yeni Kullanıcı Ekle" --text="Şifre Girin:" --hide-text)

    # Kullanıcıyı CSV dosyasına ekleyelim
    echo "$name,$username,$password" >> kullanici.csv
    zenity --info --text="Yeni kullanıcı başarıyla eklendi."
}

list_users() {
    # Kullanıcıları listele
    users=$(awk -F',' '{print "Ad: "$1 " | Kullanıcı Adı: "$2}' kullanici.csv)

    # Eğer kullanıcılar varsa, ekrana yazdıralım
    if [[ -z "$users" ]]; then
        zenity --info --text="Hiç kullanıcı bulunmamaktadır."
    else
        zenity --text-info --title="Kullanıcılar" --text="$users" --width=600 --height=400
    fi
}


update_user() {
    old_name=$(zenity --entry --title="Kullanıcı Güncelle" --text="Güncellemek İstediğiniz Kullanıcının Adını Girin:")
   
    # Kullanıcıyı bulalım
    user=$(grep -i "$old_name" kullanici.csv)

    if [[ -z "$user" ]]; then
        zenity --error --text="Kullanıcı bulunamadı!"
        return
    fi

    # Eski kullanıcı bilgilerini çekelim
    old_username=$(echo $user | awk -F',' '{print $2}')
    old_password=$(echo $user | awk -F',' '{print $3}')

    # Yeni bilgileri alalım
    new_name=$(zenity --entry --title="Kullanıcı Güncelle" --text="Yeni Kullanıcı Adını Girin:" --entry-text="$old_name")
    new_username=$(zenity --entry --title="Kullanıcı Güncelle" --text="Yeni Kullanıcı Adını (Kullanıcı Adı olarak) Girin:" --entry-text="$old_username")
    new_password=$(zenity --entry --title="Kullanıcı Güncelle" --text="Yeni Şifre Girin:" --hide-text)

    # Eski kullanıcıyı silip, yeni bilgileri ekleyelim
    sed -i "/$old_name/d" kullanici.csv
    echo "$new_name,$new_username,$new_password" >> kullanici.csv

    zenity --info --text="Kullanıcı başarıyla güncellendi."
}

delete_user() {
    name_to_delete=$(zenity --entry --title="Kullanıcı Silme" --text="Silmek İstediğiniz Kullanıcının Adını Girin:")
   
    # Kullanıcıyı bulalım
    user_to_delete=$(grep -i "$name_to_delete" kullanici.csv)

    if [[ -z "$user_to_delete" ]]; then
        zenity --error --text="Kullanıcı bulunamadı!"
        return
    fi

    # Kullanıcıyı sileceğiz
    sed -i "/$name_to_delete/d" kullanici.csv
    zenity --info --text="Kullanıcı başarıyla silindi."
}

manage_users() {
    user_action=$(zenity --list --title="Kullanıcı Yönetimi" --column="İşlemler" \
        "Yeni Kullanıcı Ekle" \
        "Kullanıcıları Listele" \
        "Kullanıcı Güncelle" \
        "Kullanıcı Silme" \
        --height=250 --width=400)

    case $user_action in
        "Yeni Kullanıcı Ekle")
            add_user
            ;;
        "Kullanıcıları Listele")
            list_users
            ;;
        "Kullanıcı Güncelle")
            update_user
            ;;
        "Kullanıcı Silme")
            delete_user
            ;;
        *)
            zenity --error --text="Geçersiz işlem seçimi!"
            ;;
    esac
}

# Program Yönetimi - Diske Yedekle
backup_to_disk() {
    backup_dir=$(zenity --file-selection --directory --title="Yedekleme Konumu Seçin")
    if [[ -z "$backup_dir" ]]; then
        zenity --error --text="Yedekleme dizini seçilmedi!"
        return
    fi

    cp depo.csv "$backup_dir"/depo_backup.csv
    cp kullanici.csv "$backup_dir"/kullanici_backup.csv
    zenity --info --text="Yedekleme başarıyla tamamlandı!"
}

# Program Yönetimi - Hata Kayıtlarını Göster
show_error_logs() {
    if [[ ! -s log.csv ]]; then
        zenity --error --text="Hata kaydı bulunmamaktadır."
        return
    fi

    zenity --text-info --title="Hata Kayıtları" --filename=log.csv --width=600 --height=400
}


# Çıkış
# Çıkış
exit_program() {
    zenity --info --text="Programdan çıkılıyor..."
    exit 0  # Çıkış işlemi sadece programı kapatır, CSV dosyasındaki verileri silmez
}


# Başlangıç
create_csv_files
user_login
