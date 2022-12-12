sudo apt-get install p7zip-full

mkdir -p ../data
cd ../data

wget https://raw.githubusercontent.com/telexyz/data/master/vi_wiki_all.txt.7z.aa
wget https://raw.githubusercontent.com/telexyz/data/master/vi_wiki_all.txt.7z.ab
cat vi_wiki_all.txt.7z.a* > vi_wiki_all.txt.7z
rm vi_wiki_all.txt.7z.a*
7z x vi_wiki_all.txt.7z

cat vi_wiki_all.txt | shuf > combined
rm combined_*
split -l 550000 combined combined_

# wget https://raw.githubusercontent.com/telexyz/data/master/news_titles.txt.7z.aa
# wget https://raw.githubusercontent.com/telexyz/data/master/news_titles.txt.7z.ab
# cat news_titles.txt.7z.a* > news_titles.txt.7z
# rm news_titles.txt.7z.a*
# 7z x news_titles.txt.7z

# wget https://raw.githubusercontent.com/telexyz/data/master/vietai_sat.txt.7z
# 7z x vietai_sat.txt.7z

# wget https://raw.githubusercontent.com/telexyz/data/master/fb_comments.txt.7z
# 7z x fb_comments.txt.7z
# split -l 2500000 fb_comments.txt fb_comments_

# wget https://raw.githubusercontent.com/telexyz/data/master/combined.txt.7z.aa
# wget https://raw.githubusercontent.com/telexyz/data/master/combined.txt.7z.ab
# cat combined.txt.7z.a* > combined.txt.7z
# rm combined.txt.7z.a*
# 7z x combined.txt.7z

# cat combined.txt | shuf > combined
# split -l 1450000 combined combined_