# InDesignファイルを対応するバージョンで開く

## 使い方
- InDesignファイル（複数可）をアプリアイコンにドラッグ＆ドロップします  
  - 対応するバージョンのInDesignがインストールされている場合、そのバージョンでファイルを開きます  
  - 対応バージョンのInDesignがインストールされていない場合は、何も実行されません  

- ファイルを開かずにバージョンのみ確認したい場合は、Optionキーを押しながらファイルをアプリアイコンにドラッグ＆ドロップしてください  
  - その後、ファイルをダブルクリックすると、対応するバージョンのInDesignで開くことができます  

- フォルダをアプリアイコンにドラッグ＆ドロップした場合も、上記と同様の動作になります  

## 注意
### 本アプリはコード署名されていません  
ダウンロード後、以下のコマンドを実行してください：

```
xattr -c path/to/OpenIndd.app
```

# Open InDesign Files with the Corresponding Version

## Usage
- Drag and drop InDesign file(s) (multiple files supported) onto the app icon  
  - If the corresponding version of InDesign is installed on your machine, the file will be opened with that version  
  - If the required version of InDesign is not installed, no action will be taken  

- To check only the file version without opening it, hold down the Option key while dragging and dropping the file onto the app icon  
  - After that, you can double-click the file to open it with the corresponding version of InDesign  

- If you drag and drop a folder onto the app icon, the same behavior as above will be applied  

## Notes
### This app is not code-signed  
After downloading, please run the following command:

```
xattr -c path/to/OpenIndd.app
```