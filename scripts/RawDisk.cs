// RawDisk.cs -- escritura y lectura cruda de discos con Windows.
//
// Por que no vale FileStream sobre \\.\PhysicalDriveN:
//   El kernel rechaza con ERROR_INVALID_PARAMETER ("El parametro no es
//   correcto") cualquier escritura con buffer a un disco raw. Exige:
//     1. FILE_FLAG_NO_BUFFERING
//     2. longitud multiple del tamano de sector
//     3. puntero alineado a sector
// Por eso aqui se usa CreateFile/WriteFile de kernel32 y un buffer
// reservado con VirtualAlloc (alineado a pagina = 4096, multiplo de 512
// y de 4096, asi que sirve para discos 512 y 4Kn).
//
// Cargado desde preparar-usb.ps1 con Add-Type -Path.
// Escrito en C# 5 a proposito: CodeDom de PowerShell 5.1 no acepta
// interpolacion de cadenas, 'out var' ni funciones de expression corporal.

using System;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;

public sealed class RawDiskWriter : IDisposable
{
    const uint GENERIC_READ       = 0x80000000;
    const uint GENERIC_WRITE      = 0x40000000;
    const uint FILE_SHARE_READ    = 0x00000001;
    const uint FILE_SHARE_WRITE   = 0x00000002;
    const uint OPEN_EXISTING      = 3;
    const uint FILE_ATTRIBUTE_NORMAL = 0x00000080;
    const uint FILE_FLAG_WRITE_THROUGH = 0x80000000;
    const uint FILE_FLAG_NO_BUFFERING  = 0x20000000;
    const uint MEM_COMMIT  = 0x1000;
    const uint MEM_RESERVE = 0x2000;
    const uint MEM_RELEASE = 0x8000;
    const uint PAGE_READWRITE = 0x04;

    // 4096 es multiplo de 512 y de 4096: vale para discos 512b y 4Kn.
    const int ALIGN = 4096;

    static readonly IntPtr INVALID_HANDLE_VALUE = new IntPtr(-1);

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern IntPtr CreateFileW(string lpFileName, uint dwDesiredAccess,
        uint dwShareMode, IntPtr lpSecurityAttributes, uint dwCreationDisposition,
        uint dwFlagsAndAttributes, IntPtr hTemplateFile);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool WriteFile(IntPtr hFile, IntPtr lpBuffer, uint nBytesToWrite,
        out uint lpBytesWritten, IntPtr lpOverlapped);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool ReadFile(IntPtr hFile, IntPtr lpBuffer, uint nBytesToRead,
        out uint lpBytesRead, IntPtr lpOverlapped);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool SetFilePointerEx(IntPtr hFile, long liDistanceToMove,
        out long lpNewFilePointer, IntPtr lpMoveMethod);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool FlushFileBuffers(IntPtr hFile);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool CloseHandle(IntPtr hObject);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern IntPtr VirtualAlloc(IntPtr lpAddress, UIntPtr dwSize,
        uint flAllocationType, uint flProtect);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool VirtualFree(IntPtr lpAddress, UIntPtr dwSize, uint dwFreeType);

    IntPtr h;
    IntPtr buf;
    byte[] managed;
    int chunk;
    long escrito;
    bool cerrado;

    public RawDiskWriter(string devicePath, int chunkMiB)
    {
        if (chunkMiB < 1) chunkMiB = 1;
        chunk = chunkMiB * 1024 * 1024;
        if (chunk % ALIGN != 0) chunk = ((chunk / ALIGN) + 1) * ALIGN;

        h = CreateFileW(devicePath, GENERIC_READ | GENERIC_WRITE,
                        FILE_SHARE_READ | FILE_SHARE_WRITE, IntPtr.Zero, OPEN_EXISTING,
                        FILE_ATTRIBUTE_NORMAL | FILE_FLAG_NO_BUFFERING | FILE_FLAG_WRITE_THROUGH,
                        IntPtr.Zero);
        if (h == INVALID_HANDLE_VALUE)
            throw new Win32Exception(Marshal.GetLastWin32Error(),
                "No se pudo abrir " + devicePath + " para escritura sin buffer");

        buf = VirtualAlloc(IntPtr.Zero, (UIntPtr)chunk, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
        if (buf == IntPtr.Zero)
        {
            int err = Marshal.GetLastWin32Error();
            CloseHandle(h);
            h = INVALID_HANDLE_VALUE;
            throw new Win32Exception(err, "VirtualAlloc no pudo reservar el buffer de escritura");
        }
        managed = new byte[chunk];
    }

    // Lee hasta 'chunk' bytes de la ISO y los escribe en el disco, ya alineados.
    // Devuelve los bytes leidos del archivo (0 = se acabo la ISO).
    public int WriteChunk(FileStream src)
    {
        if (cerrado) throw new ObjectDisposedException("RawDiskWriter");
        int n = src.Read(managed, 0, chunk);
        if (n <= 0) return 0;

        int alineado = ((n + ALIGN - 1) / ALIGN) * ALIGN;
        for (int i = n; i < alineado; i++) managed[i] = 0;

        Marshal.Copy(managed, 0, buf, alineado);

        uint escritos;
        if (!WriteFile(h, buf, (uint)alineado, out escritos, IntPtr.Zero))
            throw new Win32Exception(Marshal.GetLastWin32Error(),
                "WriteFile fallo tras " + escrito + " bytes");
        if ((int)escritos != alineado)
            throw new IOException("Escritura parcial: " + escritos + " de " + alineado + " bytes");

        escrito += alineado;
        return n;
    }

    public long Escrito { get { return escrito; } }

    public void Flush()
    {
        if (!cerrado && h != INVALID_HANDLE_VALUE) FlushFileBuffers(h);
    }

    public void Dispose()
    {
        if (cerrado) return;
        cerrado = true;
        if (buf != IntPtr.Zero) { VirtualFree(buf, UIntPtr.Zero, MEM_RELEASE); buf = IntPtr.Zero; }
        if (h != INVALID_HANDLE_VALUE) { CloseHandle(h); h = INVALID_HANDLE_VALUE; }
    }

    // Lectura cruda de un bloque. offset y count deben ser multiplos de ALIGN
    // porque la E/S va sin buffer. Devuelve el bloque completo.
    public static byte[] ReadBlock(string devicePath, long offset, int count)
    {
        if (offset % ALIGN != 0)
            throw new ArgumentException("offset debe ser multiplo de 4096 (llego " + offset + ")");
        if (count % ALIGN != 0)
            count = ((count / ALIGN) + 1) * ALIGN;

        IntPtr hh = CreateFileW(devicePath, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE,
            IntPtr.Zero, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL | FILE_FLAG_NO_BUFFERING,
            IntPtr.Zero);
        if (hh == INVALID_HANDLE_VALUE)
            throw new Win32Exception(Marshal.GetLastWin32Error(),
                "No se pudo abrir " + devicePath + " para lectura");

        IntPtr bbuf = VirtualAlloc(IntPtr.Zero, (UIntPtr)count, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
        if (bbuf == IntPtr.Zero)
        {
            int err = Marshal.GetLastWin32Error();
            CloseHandle(hh);
            throw new Win32Exception(err, "VirtualAlloc (lectura)");
        }
        try
        {
            long nueva;
            if (!SetFilePointerEx(hh, offset, out nueva, IntPtr.Zero))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "SetFilePointerEx");

            uint leidos;
            if (!ReadFile(hh, bbuf, (uint)count, out leidos, IntPtr.Zero))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "ReadFile");

            byte[] salida = new byte[count];
            Marshal.Copy(bbuf, salida, 0, count);
            return salida;
        }
        finally
        {
            VirtualFree(bbuf, UIntPtr.Zero, MEM_RELEASE);
            CloseHandle(hh);
        }
    }
}