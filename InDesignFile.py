class InDesignFile():
    def __init__(self):
        # Master page structure
        # P36, https://github.com/adobe/xmp-docs/blob/master/XMPSpecifications/XMPSpecificationPart3.pdf
        #
        # 16 byte GUID identifying this as an InDesign database
        # Must be: 0606EDF5-D81D-46e5-BD31-EFE7FE74B71D --> InDesign >= 2.0
        # except earliest versions of 1.0 and 1.5
        self.fGUID = "0606edf5d81d46e5bd31efe7fe74b71d"
        #
        # 8 bytes: type of database
        self.database = (
            "444f43554d454e54",  # DOCUMENT: .indd/indt
            "424f4f4b424f4f4b",  # BOOKBOOK: .indb
            "4c49425241525934",  # LIBRARY4: .indl
            "4c49425241525932",  # LIBRARY2: old version: InDesign2.0 / CS

        )
        # names of Adobe InDesign
        self.names = {
            # (major version, minor version), app name
            (1, 0): "1.0",
            (1, 5): "1.5",
            (2, 0): "2.0",
            (3, 0): "CS",
            (4, 0): "CS2",
            (5, 0): "CS3",
            (6, 0): "CS4",
            (7, 0): "CS5",
            (7, 5): "CS5.5",
            (8, 0): "CS6",
            (9, 0): "CC",
            (10, 0): "CC 2014",
            (11, 0): "CC 2015",
            (12, 0): "CC 2017",  # NOTE: CC 2016 does not exists
            (13, 0): "CC 2018",
            (14, 0): "CC 2019",
            # >=InDesign 2020: 2005 + major_version
        }

    def get_version(self, file: str, check_fGUID=True) -> tuple:
        # return: ((major version[int], minor_version[int]), app_name)
        #    Example: ((18, 0), 'Adobe InDesign 2023')
        with open(file, "rb") as f:
            fGUID = f.read(16).hex()
            if fGUID != self.fGUID:
                if check_fGUID:
                    return None, "Not a InDesign file"
                else:  # maybe V1.0/1.5
                    f.seek(92)  # go to the position of database
            b = f.read(24)
        fMagicBytes = b[:8].hex()
        if fMagicBytes not in self.database:
            return None, "Not a InDesign file."
        # Endian of object streams, 1=little endian, 2=big endian
        fObjectStreamEndian = b[8]
        if fObjectStreamEndian == 1:
            major_version, minor_version = b[13], b[17]
        elif fObjectStreamEndian == 2:
            major_version, minor_version = b[16], b[20]
        else:
            raise f"Invalid endian of object streams: {fObjectStreamEndian}"
        #
        app_name = self.__get_app_name(major_version, minor_version)
        return (major_version, minor_version), app_name

    def __get_app_name(self, major_version, minor_version):
        # get InDesign app str name
        v = 0
        if major_version in (1, 7) and minor_version == 5:  # v1.5/7.5
            v = 5
        return f"Adobe InDesign {self.names.get((major_version, v), 2005 + major_version)}"
