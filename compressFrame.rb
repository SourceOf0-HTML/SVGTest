##############################
#
# Mohoで出力したSVGに
# グループレイヤーのマスクを付与
#
# MEMO
# レイヤー名に命名規則あり
# MtargetとMaskの１対１しか対応してないので注意
#
##############################

require "pathname"

source_dir = Pathname("source")
destination_dir = Pathname("destination")
file_count = 0
merge_count = 0
merge_num = 24
isFirst = true
fileArr = Pathname.glob(source_dir.join("**/*"))
load_count = 0
classList = []

fileArr.each do |source_path|
  # ファイルじゃないとき（ディレクトリーのとき）はスキップ
  next unless source_path.file?

  # 接頭語
  filePrefix = source_path.basename.to_s.match(/(.+)_\d+/)[1]

  # 保存先のパス
  destination_path = destination_dir.join("#{filePrefix}_#{sprintf("%03d",file_count)}.svg")

  # ディレクトリーを必要に応じて作成
  destination_path.dirname.mkpath

  # 新規か追記か判定
  op = (merge_count == 0)? "w" : "a"

  # 書き出し
  destination_path.open op do |f|
    
    load_count += 1
    
    isSVG = false
    idName = ""
    elementCount = 0
    elementID = ""
    isClip = false
    clipDataArr = []
    clipCount = 0
    clipID = ""
    
    # 元ファイルの各行について繰り返し
    source_path.each_line do |line|
      
      # コメントアウトはスキップ
      next if (line.start_with?("<!--") && line.end_with?("-->\n"))
      
      unless isSVG
        # まだデータ本体まで辿り着いてない
        if line.start_with?("<svg") then
          # 本体発見
          
          # 属性抽出
          idName = line[/id=\"(.+?)\"/, 1]
          width = line[/width=\"(.+?)px\"/, 1]
          height = line[/height=\"(.+?)px\"/, 1]
          
          if isFirst then
            # svgタグを出力
            f.puts line.gsub(/ id=\".+?\"/, "").gsub(/width=\".+?px\"/, "width=\"0\"").gsub(/height=\".+?px\"/, "height=\"0\"")
            f.puts "<defs>"
            isFirst = false
          end
          f.puts "<symbol id=\"#{idName}\" viewBox=\"0 0 #{width} #{height}\">"
          isSVG = true
        end
        # 終了
        next
      end
      
      if line.start_with?("</svg>") then
        # 終端発見
        f.puts "</symbol>"
        
        merge_count = (merge_count + 1) % merge_num
        if (merge_count == 0) || (fileArr.length == load_count) then
          f.puts "</defs>"
          
          # デザイン属性をCSS形式で出力
          f.puts "<style>"
          classList.each_with_index {|data, i|
            f.puts ".path-#{i}{#{data.gsub("=\"", ":").gsub("\"", ";")}}"
          }
          f.puts "</style>"
          
          f.puts "</svg>"
          file_count += 1
          isFirst = true
        end
        
        # 終了
        next
      end
      
      # 座標データを圧縮
      line.sub!(/ d=\"(.+?)\"/) {
        " d=\"#{$1.strip.gsub(/ *([a-zA-Z\-]) */, '\1').gsub(" ", ",")}\""
      }
      
      # デザイン属性を検索＆共通化
      if line.start_with?("<path ") then
        attr = line[/<path (.+) d=/, 1]
        index = classList.index(attr)
        unless index then
          # 新規属性を追加
          index = classList.length
          classList.push(attr)
        end
        # クラスに置換
        line.sub!(attr, "class=\"path-#{index}\"")
      end
      
      
      # id補正
      line.gsub!(/ id=\".+?\"/, " id=\"#{idName}_#{line[/id=\"(.+?)\"/, 1]}\"")
      line.gsub!(/ clip-path=\"url\(#.+?\)\"/, " clip-path=\"url(\##{idName}_#{line[/clip-path=\"url\(#(.+?)\)\"/, 1]}\)\"")
      
      # clipPathをMaskに置換＆useによる参照に変更
      line.sub!("clip-path=", "mask=")
      if line.start_with?("<clipPath") then
        clipCount = 0
        clipID = "cmn_" + line[/id=\"(.+?)\"/, 1]
        line.sub!("<clipPath", "<mask style=\"mask-type:alpha;\"")
        isClip = true
        
      elsif isClip then
        if line.start_with?("</clipPath>") then
          # Mask終端
          isClip = false
        else
          # チェック用に退避
          clipCount += 1
          clipDataArr.unshift(line)
        end
        # データ退避中なのでスキップ
        next
        
      elsif clipCount > 0 then
        # データが一致するかチェックする
        clipCount -= 1
        if clipDataArr[clipCount] != line then
          # 同じではないので退避していたデータと比較済み部分を出力
          str  = clipDataArr.reverse.join
          str += "</mask>\n"
          str += clipDataArr.slice(clipCount, clipDataArr.length - clipCount).reverse.join
          line = line + str
          clipCount = 0
          
        elsif clipCount == 0 then
          # 一致するデータなのでuseに置き換える
          line = "<use xlink:href=\"##{idName}_#{clipID}\"/>\n"
          line += "</mask>\n"
          line += "<g id=\"#{idName}_#{clipID}\">\n"
          line += clipDataArr.reverse.join
          line += "</g>\n"
          clipDataArr.clear
          
        else 
          # データ一致チェック中なので出力しない
          next
        end
        
      end
      
      # グループレイヤーにマスクを付与
      if line.match(/id=\".+?_Mtarget\"/) then
        # ターゲット用の属性を付与
        line.sub!(">", " mask=\"url(##{idName}_mask_target)\">")
        
      elsif line.match(/id=\".+?_Mask\"/) then
        # マスク用データを初期化
        elementCount = 1
        elementID = line[/id=\"(.+?_Mask)\"/, 1]
        
      elsif elementCount > 0 then
        if line.start_with?("</") then
          if elementCount == 1 then
            # 元データの終端を出力
            
            # マスク該当箇所終端のためマスクを出力
            line += "<mask id=\"#{idName}_mask_target\" style=\"mask-type:alpha;\">\n"
            line += "<use xlink:href=\"##{elementID}\"/>\n"
            line += "</mask>\n"
            elementCount = 0
            elementID = ""
            
          else
            # 要素の階層を下げる
            elementCount -= 1
          end
          
        elsif !line.end_with?("/>\n") then
          # 要素が閉じていないので階層を上げる
          elementCount += 1
        end
        
      end
      
      
      # 出力
      #f.puts line
      f.print line.gsub(/[\r\n]/,"")
      
    end
    
  end
  
end
