"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { Button, SectionHeading } from "@/components/ui";
import { ErrorNotice, UnexpectedErrorNotice } from "@/components/feedback";
import { apiGet } from "@/lib/api";
import { spellChoice, spellDateTime } from "@/lib/format";
import { text } from "@/strings";
import { ApiError } from "@/types/api";
import {
  DELIVERED_STATUSES,
  type Project,
  type ProjectList,
  type PromptRequestList,
  type PromptRequestSummary,
} from "@/types/resources";
import styles from "./projects.module.css";

/** 一覧をすべて表示することを表す値です。 */
const ALL_PROJECTS = "";

/**
 * 履歴・一覧（02）です（issue #70）。
 *
 * **過去の生成を開き直せます。** 受け取り済みの案は、結果の画面から
 * そのまま読めます。
 *
 * **同じ条件で作り直せます。** 入力フォームへ、そのプロジェクトを
 * 選んだ状態で移ります。
 *
 * **縮退の印を一覧に出します**（requirements.md 4.2）。どの案が
 * 規則辞書だけで組み立てられたのかを、開かずに見分けられます。
 */
export function Projects() {
  const { projects, requests, error, loading } = useHistory();
  const [projectId, setProjectId] = useState<string>(ALL_PROJECTS);

  const shown = useMemo(
    () =>
      projectId === ALL_PROJECTS
        ? requests
        : requests.filter((item) => String(item.project_id) === projectId),
    [requests, projectId],
  );

  if (error) {
    return error instanceof ApiError ? (
      <ErrorNotice error={error} />
    ) : (
      <UnexpectedErrorNotice />
    );
  }

  return (
    <div className={styles.section}>
      <SectionHeading
        eyebrow={text("projects.labels.eyebrow")}
        title={text("projects.labels.title")}
      >
        {text("projects.body")}
      </SectionHeading>

      <ProjectPanel projects={projects} loading={loading} />

      <div className={styles.filter}>
        <label htmlFor="project-filter">{text("projects.labels.filterLabel")}</label>
        <select
          id="project-filter"
          className={styles.select}
          value={projectId}
          onChange={(event) => setProjectId(event.target.value)}
        >
          <option value={ALL_PROJECTS}>{text("projects.labels.filterAll")}</option>
          {projects.map((project) => (
            <option key={project.id} value={String(project.id)}>
              {nameOf(project)}
            </option>
          ))}
        </select>
      </div>

      <RequestPanel requests={shown} loading={loading} />
    </div>
  );
}

/** プロジェクトの表示名です。**名前が無ければ業種で表します。** */
function nameOf(project: Project): string {
  return project.name ?? spellChoice("industry", project.industry);
}

function ProjectPanel({
  projects,
  loading,
}: {
  projects: Project[];
  loading: boolean;
}) {
  return (
    <section className={styles.panel}>
      {/* **目で見る方にも、何の一覧かが分かるようにします。** */}
      <h3 className={styles.panelHeading}>{text("projects.labels.projectsHeading")}</h3>
      {loading ? <p className={styles.loading}>{text("projects.loading")}</p> : null}
      {!loading && projects.length === 0 ? (
        <p className={styles.empty}>{text("projects.emptyProjects")}</p>
      ) : null}
      {projects.map((project) => (
        <div key={project.id} className={styles.row}>
          <div className={styles.rowMain}>
            <span className={styles.rowTitle}>{nameOf(project)}</span>
            <span className={styles.rowMeta}>
              {spellChoice("industry", project.industry)}
              {text("common.labels.separator")}
              {spellChoice("styleFamily", project.style_family)}
            </span>
          </div>
        </div>
      ))}
    </section>
  );
}

function RequestPanel({
  requests,
  loading,
}: {
  requests: PromptRequestSummary[];
  loading: boolean;
}) {
  return (
    <section className={styles.panel}>
      <h3 className={styles.panelHeading}>{text("projects.labels.requestsHeading")}</h3>
      {loading ? <p className={styles.loading}>{text("projects.loading")}</p> : null}
      {!loading && requests.length === 0 ? (
        <p className={styles.empty}>{text("projects.emptyRequests")}</p>
      ) : null}
      {requests.map((request) => (
        <RequestRow key={request.id} request={request} />
      ))}
    </section>
  );
}

function RequestRow({ request }: { request: PromptRequestSummary }) {
  const delivered = DELIVERED_STATUSES.includes(request.status);

  return (
    <div className={styles.row}>
      <div className={styles.rowMain}>
        <span className={styles.rowTitle}>
          {spellChoice("status", request.status)}
        </span>
        <span className={styles.rowMeta}>
          {spellDateTime(request.created_at)}
          {text("common.labels.separator")}
          {spellChoice("targetModel", request.target_model)}
          {text("common.labels.separator")}
          {request.outputs_count}
          {text("projects.labels.outputsUnit")}
        </span>
      </div>

      <div className={styles.badges}>
        {/* **縮退の印です。** 開かずに見分けられます。 */}
        {request.degraded ? (
          <span className={`${styles.badge} ${styles.badgeDegraded}`}>
            {text("projects.labels.degraded")}
          </span>
        ) : null}
        {delivered ? (
          <span className={`${styles.badge} ${styles.badgeDelivered}`}>
            {text("projects.labels.delivered")}
          </span>
        ) : null}
      </div>

      <div className={styles.actions}>
        <Link href={`/requests/${request.id}`}>{text("projects.labels.open")}</Link>
        {/* **同じ条件で作り直します。** 入力条件は、もとの生成リクエストから
            そのまま引き継ぎます（PR #174 のレビュー・重大 3）。 */}
        <Button
          variant="outline"
          href={`/requests/new?project_id=${request.project_id}&request_id=${request.id}`}
          icon="rotate-right"
          iconPosition="start"
        >
          {text("projects.labels.duplicate")}
        </Button>
      </div>
    </div>
  );
}

interface History {
  projects: Project[];
  requests: PromptRequestSummary[];
  error: unknown;
  loading: boolean;
}

/**
 * プロジェクトと生成履歴を引きます。
 *
 * **上限に達していても引けます。** 閲覧は生成ではありません。
 */
function useHistory(): History {
  const [projects, setProjects] = useState<Project[]>([]);
  const [requests, setRequests] = useState<PromptRequestSummary[]>([]);
  const [error, setError] = useState<unknown>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const controller = new AbortController();

    Promise.all([
      apiGet<ProjectList>("/projects", { signal: controller.signal }),
      apiGet<PromptRequestList>("/prompt_requests", { signal: controller.signal }),
    ])
      .then(([projectList, requestList]) => {
        setProjects(projectList.projects);
        setRequests(requestList.prompt_requests);
        setLoading(false);
      })
      .catch((cause) => {
        if (controller.signal.aborted) {
          return;
        }
        setError(cause);
        setLoading(false);
      });

    return () => controller.abort();
  }, []);

  return { projects, requests, error, loading };
}
