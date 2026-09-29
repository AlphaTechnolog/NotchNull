import { AgentsSection } from "@/components/AgentsSection";
import { FeatureGrid } from "@/components/FeatureGrid";
import { Footer } from "@/components/Footer";
import { Hero } from "@/components/Hero";
import { InstallSection } from "@/components/InstallSection";
import { Nav } from "@/components/Nav";
import { PanelTabs } from "@/components/PanelTabs";
import { PrivacySection } from "@/components/PrivacySection";

export default function Home() {
  return (
    <>
      <Nav />
      <main>
        <Hero />
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
