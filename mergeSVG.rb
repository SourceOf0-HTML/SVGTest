require "pathname"

source_dir = Pathname("source")
destination_dir = Pathname("destination")
destination_path = destination_dir.join("result.svg")

# ディレクトリーを必要に応じて作成
destination_path.dirname.mkpath

# 書き出し
destination_path.open "w" do |f|
  
  isFirst = true
  
  Pathname.glob(source_dir.join("**/*")) do |source_path|
    # ファイルじゃないとき（ディレクトリーのとき）はスキップ
    next unless source_path.file?
    
    # source_dir から見た相対パス
    rel_path = source_path.relative_path_from source_dir
    
    isSVG = false
    id_name = ""
    elementCount = 0
    elementStr = ""
    
    # 元ファイルの各行について繰り返し
    source_path.each_line do |line|
      
      # コメントアウトはスキップ
      next if (line.start_with?("<!--") && line.end_with?("-->\n"))
      
      unless isSVG
        # まだデータ本体まで辿り着いてない
        if line.start_with?("<svg") then
          # 本体発見
          
          # 属性抽出
          id_name = line[/id=\"(.+?)\"/, 1]
          width = line[/width=\"(.+?)px\"/, 1]
          height = line[/height=\"(.+?)px\"/, 1]
          
          if isFirst
            # svgタグを出力
            f.puts line.gsub(/ id=\".+?\"/, "").gsub(/width=\".+?px\"/, "width=\"0\"").gsub(/height=\".+?px\"/, "height=\"0\"")
            f.puts "<defs>"
            isFirst = false
          end
          f.puts "<symbol id=\"#{id_name}\" viewBox=\"0 0 #{width} #{height}\">"
          isSVG = true
        end
        # 終了
        next
      end
      
      if line.start_with?("</svg>") then
        f.puts "</symbol>"
        # 終了
        next
      end
      
      # id補正
      line.gsub!(/ id=\".+?\"/, " id=\"#{id_name}_#{line[/id=\"(.+?)\"/, 1]}\"")
      line.gsub!(/ clip-path=\"url\(#.+?\)\"/, " clip-path=\"url(\##{id_name}_#{line[/clip-path=\"url\(#(.+?)\)\"/, 1]}\)\"")
      
      if line.include?("Mtarget") then
        # ターゲット用の属性を付与
        f.puts line.sub(">", " clip-path=\"url(##{id_name}_mask_target)\">")
      
      elsif line.include?("Mask") then
        f.puts line
        
        # マスク用データを初期化
        elementStr = "<clipPath id=\"#{id_name}_mask_target\">\n"
        elementCount = 1
        #f.puts "[FOUND]"
        
      elsif elementCount > 0 then
        
        if line.start_with?("<path") then
          # マスク用データに格納しつつ出力
          elementStr += line
          f.puts line
          
        elsif line.start_with?("</") then
          if elementCount == 1 then
            # マスク該当箇所終端のためマスクを出力
            elementStr += "</clipPath>"
            f.puts elementStr
            elementCount = 0
            
            # 元データの終端を出力
            f.puts line
            #f.puts "[END]"
            
          else
            # マスク用データに格納しつつ出力
            elementStr += line
            f.puts line
            
            # 要素の階層を下げる
            elementCount -= 1
            #f.puts "[DOWN]"
          end
          
        elsif line.start_with?("<") then
          # マスク用データに格納しつつ出力
          elementStr += line
          f.puts line
          
          # 要素の階層を上げる
          elementCount += 1
          #f.puts "[ADD]"
        end

      else
        # そのまま出力
        f.puts line
      end
      
    end
    
  end
  
  f.puts "</defs>"
  f.puts "</svg>"
  
end
