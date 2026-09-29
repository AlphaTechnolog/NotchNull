import type { ReactNode } from "react";

type ScreenProps = {
  children: ReactNode;
  className?: string;
  height?: string;
  /** Without the menu bar, for screens too narrow to show it beside the notch. */
  bare?: boolean;
};

/**
 * The top of a MacBook display: bezel, wallpaper and menu bar, with the notch content hanging
 * from the top center — the same place it lives in the real app. The lower edge fades into the
 * page so the screen reads as part of the black surface rather than a framed picture.
 */
export function Screen({ children, className = "", height = "h-[300px] sm:h-[360px]", bare = false }: ScreenProps) {
  return (
    <div
      className={`relative w-full overflow-hidden rounded-t-[22px] bg-[#0a0a0b] p-[6px] pb-0 shadow-[inset_0_1px_0_rgb(255_255_255/0.14),0_0_0_1px_rgb(255_255_255/0.08)] [mask-image:linear-gradient(to_bottom,black_74%,transparent)] ${className}`}
    >
      <div className={`relative overflow-hidden rounded-t-[16px] bg-[url(/brand/wallpaper.jpg)] bg-cover bg-[center_top] ${height}`}>
        {!bare && <MenuBar />}
        <div className="absolute inset-x-0 top-0 flex h-full justify-center">{children}</div>
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
