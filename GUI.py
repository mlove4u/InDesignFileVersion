import os
import csv
import wx
import wx.lib.mixins.listctrl as listmix
from InDesignFile import InDesignFile


class FileDropTarget(wx.FileDropTarget):
    def __init__(self, parent):
        wx.FileDropTarget.__init__(self)
        self.parent = parent

    def OnDropFiles(self, x, y, files):
        self.parent.check(files)
        return 0


class SortableListCtrl(wx.ListCtrl, listmix.ListCtrlAutoWidthMixin):
    def __init__(self, parent):
        wx.ListCtrl.__init__(self, parent, -1,
                             style=wx.LC_REPORT | wx.LC_SINGLE_SEL)
        listmix.ListCtrlAutoWidthMixin.__init__(self)
        #
        self.parent = parent
        self.sort_acend = True
        self.pre_column = None  # column number last clicked
        #
        self.Bind(wx.EVT_LIST_COL_CLICK, self.__sort)

    def set_header(self, datas: list):
        # datas: [(name:str, width:int),...]
        # width:int == -1: auto width
        for i, x in enumerate(datas):
            self.InsertColumn(i, x[0], width=x[1])

    def set_datas(self, data):
        self.items = data
        self.__insert_datas()

    def __insert_datas(self):
        self.DeleteAllItems()
        for i, x in enumerate(self.items):
            self.InsertItem(i, x[0])
            self.SetItem(i, 1, str(x[1]))  # tuple to str
            self.SetItem(i, 2, x[2])
            if x[1] == (-1, -1):
                self.SetItemTextColour(i, "Red")

    def __sort(self, event):
        col = event.GetColumn()
        if col != self.pre_column:  # click on a new column
            self.sort_acend = True
            self.pre_column = col
        else:
            self.sort_acend = not self.sort_acend
        if self.sort_acend:
            self.items.sort(key=lambda x: x[col])
        else:
            self.items.sort(key=lambda x: x[col], reverse=True)
        self.__insert_datas()


class MyFrame (wx.Frame):

    def __init__(self):
        wx.Frame.__init__(self, parent=None, id=-1, size=(600, 600),
                          title="Check InDesign File Version")
        #
        sbSizer = wx.StaticBoxSizer(wx.StaticBox(self, -1, "File extension"))
        self.indd = wx.CheckBox(sbSizer.GetStaticBox(), -1, "indd")
        self.indd.SetValue(True)  # default: check indd only
        self.indt = wx.CheckBox(sbSizer.GetStaticBox(), -1, "indt")
        self.indb = wx.CheckBox(sbSizer.GetStaticBox(), -1, "indb")
        self.indl = wx.CheckBox(sbSizer.GetStaticBox(), -1, "indl")
        for obj in (self.indd, self.indt, self.indb, self.indl):
            sbSizer.Add(obj, 0, wx.ALL, 5)
        #
        self.btn = wx.Button(self, -1, "Export as CSV")
        #
        self.table = SortableListCtrl(self)
        self.table.SetDropTarget(FileDropTarget(self))  # drag&drop area
        self.table_header = [("App Name", 170), ("Version", 60), ("File", -1)]
        self.table.set_header(self.table_header)
        #
        main_sizer = wx.BoxSizer(wx.VERTICAL)
        main_sizer.Add(sbSizer, 0, wx.ALL, 5)
        main_sizer.Add(self.btn, 0, wx.ALIGN_RIGHT | wx.ALL, 5)
        main_sizer.Add(self.table, 1, wx.ALL | wx.EXPAND, 5)
        self.SetSizer(main_sizer)
        self.Layout()
        #
        self.btn.Bind(wx.EVT_BUTTON, self.export_to_csv)
        #
        self.myInDesignFile = InDesignFile()

    def __get_files_in_folder(self, folder, suffixs):
        for root, _, files in os.walk(folder):
            for f in files:
                if (not f.startswith(".")) and f.lower().endswith(suffixs):
                    yield os.path.join(root, f)

    def check(self, files):
        objs = {".indd": self.indd, ".indt": self.indt,
                ".indb": self.indb, ".indl": self.indl}
        suffixs = tuple([k for k in objs if objs[k].GetValue()])
        #
        results = []
        files_to_check = []
        for f in files:
            if os.path.isfile(f):
                if f.lower().endswith(suffixs):
                    files_to_check.append(f)
            else:  # folder
                for y in self.__get_files_in_folder(f, suffixs):
                    files_to_check.append(y)
        for f in files_to_check:
            # NOTE: do not check fGUID!
            r = self.myInDesignFile.get_version(f, check_fGUID=False)
            version = (-1, -1) if r[0] == None else r[0]
            results.append([r[1], version, f])
        self.table.set_datas(results)

    def export_to_csv(self, event):
        # save csv to ~/Desktop/__result.csv
        saveto = os.path.join(os.path.expanduser('~/Desktop'), "__result.csv")
        with open(saveto, 'w', encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow([x[0] for x in self.table_header])  # header
            for row in self.table.items:
                writer.writerow(row)


if __name__ == '__main__':
    app = wx.App()
    frame = MyFrame()
    frame.Show()
    app.MainLoop()
