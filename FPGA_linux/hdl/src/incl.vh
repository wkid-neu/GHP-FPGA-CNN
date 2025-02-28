`define M64P64Q16R16S8

`ifdef M32P32Q16R32S4
    `include "conf/__M32P32Q16R32S4_incl.vh"
`endif
`ifdef M32P32Q16R16S8
    `include "conf/__M32P32Q16R16S8_incl.vh"
`endif
`ifdef M32P64Q16R32S4
    `include "conf/__M32P64Q16R32S4_incl.vh"
`endif
`ifdef M32P64Q16R16S8
    `include "conf/__M32P64Q16R16S8_incl.vh"
`endif
`ifdef M32P96Q16R32S4
    `include "conf/__M32P96Q16R32S4_incl.vh"
`endif
`ifdef M32P96Q16R16S8
    `include "conf/__M32P96Q16R16S8_incl.vh"
`endif
`ifdef M64P64Q16R32S4
    `include "conf/__M64P64Q16R32S4_incl.vh"
`endif
`ifdef M64P64Q16R16S8
    `include "conf/__M64P64Q16R16S8_incl.vh"
`endif
