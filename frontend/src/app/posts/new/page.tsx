"use client"; // このファイルはブラウザで動かす（付けないとサーバー側で動く）

import { useRouter } from "next/navigation";
import { useState } from "react";
import PostForm, { type PostFormValues } from "@/components/PostForm";
import { getAccessToken } from "@/lib/auth";

export default function NewPostPage() {
  const router = useRouter();
  const [errors, setErrors] = useState<string[]>([]);

  async function handleSubmit(values: PostFormValues) {
    const token = getAccessToken();
    // API に記事の作成を依頼する（POST /posts）
    const res = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/posts`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        // ログインしていれば「Authorization: Bearer （トークン）」を付ける
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: JSON.stringify(values),
    });

    if (!res.ok) {
      // 400 のときは message が配列、それ以外は文字列で返る（→ 3-2-13）
      const data = await res.json();
      setErrors(Array.isArray(data.message) ? data.message : [data.message]);
      return;
    }

    router.push("/"); // 作成できたら一覧に戻る
  }

  return (
    <main>
      <h1>新しい記事</h1>
      <PostForm submitLabel="作成" errors={errors} onSubmit={handleSubmit} />
    </main>
  );
}
