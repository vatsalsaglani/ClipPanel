import { Nav } from "@/components/nav";
import { Hero } from "@/components/sections/hero";
import { Problem } from "@/components/sections/problem";
import { HowItWorks } from "@/components/sections/how-it-works";
import { FeatureGrid } from "@/components/sections/feature-grid";
import { Privacy } from "@/components/sections/privacy";
import { NativeQuality } from "@/components/sections/native-quality";
import { KeyboardReference } from "@/components/sections/keyboard-reference";
import { HonestScope } from "@/components/sections/honest-scope";
import { Faq } from "@/components/sections/faq";
import { FinalCta } from "@/components/sections/final-cta";
import { Footer } from "@/components/sections/footer";

export default function Page() {
  return (
    <>
      <Nav />
      <main>
        <Hero />
        <Problem />
        <HowItWorks />
        <FeatureGrid />
        <Privacy />
        <NativeQuality />
        <KeyboardReference />
        <HonestScope />
        <Faq />
        <FinalCta />
      </main>
      <Footer />
    </>
  );
}
