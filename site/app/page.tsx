import { AgentsSection } from "@/components/AgentsSection";
import { BuildSection } from "@/components/BuildSection";
import { FeatureGrid } from "@/components/FeatureGrid";
import { Footer } from "@/components/Footer";
import { Hero } from "@/components/Hero";
import { InstallSection } from "@/components/InstallSection";
import { Nav } from "@/components/Nav";
import { PanelTabs } from "@/components/PanelTabs";
import { PrivacySection } from "@/components/PrivacySection";
import { Statement } from "@/components/Statement";
import { YoursSection } from "@/components/YoursSection";

export default function Home() {
  return (
    <>
      <Nav />
      <main>
        <Hero />
        <Statement />
        <BuildSection />
        <YoursSection />
        <AgentsSection />
        <PanelTabs />
        <FeatureGrid />
        <PrivacySection />
        <InstallSection />
      </main>
      <Footer />
    </>
  );
}
