import type { ReactNode } from "react";

type ScreenProps = { children: ReactNode; className?: string; height?: string };

/**
 * The top of a MacBook display: bezel, wallpaper and menu bar, with the notch content
 * hanging from the top center — the same place it lives in the real app.
 */
export function Screen({ children, className = "", height = "h-[300px] sm:h-[360px]" }: ScreenProps) {
  return (
    <div
      className={`relative w-full overflow-hidden rounded-t-[22px] border border-b-0 border-white/10 bg-black p-[6px] pb-0 shadow-[0_40px_120px_-20px_rgb(167_139_250/0.25)] ${className}`}
    >
      <div
        className={`relative overflow-hidden rounded-t-[16px] bg-[url(/brand/wallpaper.jpg)] bg-cover bg-[center_top] ${height}`}
      >
        <MenuBar />
        <div className="absolute inset-x-0 top-0 flex justify-center">{children}</div>
      </div>
    </div>
  );
}

function MenuBar() {
  return (
    <div className="absolute inset-x-0 top-0 flex h-[32px] items-center justify-between bg-black/30 px-4 text-[12px] font-medium text-white/80 backdrop-blur-sm">
      <div className="flex items-center gap-4">
        <span className="font-semibold">Terminal</span>
        <span className="hidden text-white/60 sm:inline">File</span>
        <span className="hidden text-white/60 sm:inline">Edit</span>
        <span className="hidden text-white/60 sm:inline">View</span>
      </div>
      <span className="tabular-nums text-white/70">Tue 9:41 AM</span>
    </div>
  );
}
