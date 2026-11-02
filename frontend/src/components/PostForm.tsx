"use client";

import { useState } from "react";
import { uploadImage } from "@/lib/upload";

export type PostFormValues = {
  title: string;
  body: string;
  status: string;
  imageKey?: string;
};

type Props = {
  initialValues?: PostFormValues;
  submitLabel: string;
  errors: string[];
  onSubmit: (values: PostFormValues) => void;
};

// 作成ページと編集ページで共通のフォーム
// 入力値はこの部品が持ち、送信先（POST か PATCH か）は呼ぶ側のページが決める
export default function PostForm({
  initialValues = { title: "", body: "", status: "draft" },
  submitLabel,
  errors,
  onSubmit,
}: Props) {
  const [title, setTitle] = useState(initialValues.title);
  const [body, setBody] = useState(initialValues.body);
  const [status, setStatus] = useState(initialValues.status);
  const [file, setFile] = useState<File | null>(null);

  async function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    // 画像が選ばれていれば、先に S3 に置いてキーを受け取る
    const imageKey = file ? await uploadImage(file) : initialValues.imageKey;
    onSubmit({ title, body, status, imageKey });
  }

  return (
    <>
      {errors.map((message) => (
        <p key={message} className="error">
          {message}
        </p>
      ))}
      <form onSubmit={handleSubmit}>
        <label>
          タイトル
          <input value={title} onChange={(e) => setTitle(e.target.value)} />
        </label>
        <label>
          本文
          <textarea
            rows={8}
            value={body}
            onChange={(e) => setBody(e.target.value)}
          />
        </label>
        <label>
          状態
          <select value={status} onChange={(e) => setStatus(e.target.value)}>
            <option value="draft">下書き</option>
            <option value="published">公開</option>
          </select>
        </label>
        <label>
          画像
          <input
            type="file"
            accept="image/jpeg,image/png,image/gif,image/webp"
            onChange={(e) => setFile(e.target.files?.[0] ?? null)}
          />
        </label>
        <button type="submit">{submitLabel}</button>
      </form>
    </>
  );
}
