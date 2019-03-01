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

Pathname.glob(source_dir.join("**/*")) do |source_path|
  # ファイルじゃないとき（ディレクトリーのとき）はスキップ
  next unless source_path.file?

  # source_dir から見た相対パス
  rel_path = source_path.relative_path_from source_dir

  # 保存先のパス
  destination_path = destination_dir.join(rel_path)

  # ディレクトリーを必要に応じて作成
  destination_path.dirname.mkpath

  # 書き出し
  destination_path.open "w" do |f|
  
    isSVG = false
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
          isSVG = true
        else
          # スキップ
          next
        end
      end
      
      
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
          line = "<use xlink:href=\"##{clipID}\"/>\n"
          line += "</mask>\n"
          line += "<g id=\"#{clipID}\">\n"
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
        line.sub!(">", " mask=\"url(#mask_target)\">")
        
      elsif line.match(/id=\".+?_Mask\"/) then
        # マスク用データを初期化
        elementCount = 1
        elementID = line[/id=\"(.+?_Mask)\"/, 1]
        
      elsif elementCount > 0 then
        if line.start_with?("</") then
          if elementCount == 1 then
            # 元データの終端を出力
            
            # マスク該当箇所終端のためマスクを出力
            line += "<mask id=\"mask_target\" style=\"mask-type:alpha;\">\n"
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
