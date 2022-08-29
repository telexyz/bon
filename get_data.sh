mkdir -p ../data
cd ../data

wget https://raw.githubusercontent.com/telexyz/data/master/vi_wiki_all.txt.7z.aa
wget https://raw.githubusercontent.com/telexyz/data/master/vi_wiki_all.txt.7z.ab
cat vi_wiki_all.txt.7z.a* > vi_wiki_all.txt.7z
rm vi_wiki_all.txt.7z.a*
open vi_wiki_all.txt.7z

wget https://raw.githubusercontent.com/telexyz/data/master/news_titles.txt.7z.aa
wget https://raw.githubusercontent.com/telexyz/data/master/news_titles.txt.7z.ab
cat news_titles.txt.7z.a* > news_titles.txt.7z
rm news_titles.txt.7z.a*
open news_titles.txt.7z

# wget https://raw.githubusercontent.com/telexyz/data/master/vietai_sat.txt.7z
# open vietai_sat.txt.7z

wget https://raw.githubusercontent.com/telexyz/data/master/fb_comments.txt.7z
open fb_comments.txt.7z
split -l 2500000 fb_comments.txt fb_comments_

wget https://raw.githubusercontent.com/telexyz/data/master/combined.txt.7z.aa
wget https://raw.githubusercontent.com/telexyz/data/master/combined.txt.7z.ab
cat combined.txt.7z.a* > combined.txt.7z
rm combined.txt.7z.a*
open combined.txt.7z

split -l 1875000 combined_ab combined_ab_
mv combined_ab_aa combined_ae
mv combined_ab_ab combined_ab
