import {
  Activity,
  BatteryCharging,
  BellRing,
  CircleCheck,
  ClipboardList,
  Cpu,
  Download,
  Gauge,
  Headphones,
  Music,
  Timer,
  Inbox,
  Volume2,
  type LucideIcon,
} from "lucide-react";

const icons: Record<string, LucideIcon> = {
  Activity,
  BatteryCharging,
  BellRing,
  CircleCheck,
  ClipboardList,
  Cpu,
  Download,
  Gauge,
  Headphones,
  Music,
  Timer,
  Inbox,
  Volume2,
};

/** Resolves an icon name from content/site.ts to its lucide component. */
export function Icon({ name, className }: { name: string; className?: string }) {
  const Component = icons[name];
  if (!Component) throw new TypeError(`[SITE]: unknown icon "${name}"`);
  return <Component className={className} aria-hidden="true" strokeWidth={1.8} />;
}
