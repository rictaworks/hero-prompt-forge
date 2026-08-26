import type { Metadata } from "next";
import { AppShell } from "@/components/app/AppShell";
import { Projects } from "@/components/projects";
import { text } from "@/strings";

export const metadata: Metadata = {
  title: text("projects.labels.title"),
};

export default function ProjectsPage() {
  return (
    <AppShell active="projects">
      <Projects />
    </AppShell>
  );
}
