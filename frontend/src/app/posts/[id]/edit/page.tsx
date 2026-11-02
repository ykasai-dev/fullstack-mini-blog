"use client"; // このファイルはブラウザで動かす（付けないとサーバー側で動く）

import { useParams, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import PostForm, { type PostFormValues } from "@/components/PostForm";
import { getAccessToken } from "@/lib/auth";

export default function EditPostPage() {
  const { id } = useParams<{ id: string }>(); // URL の [id] の部分
  const router = useRouter();
  const [initialValues, setInitialValues] = useState<PostFormValues | null>(
    null,
  );
  const [errors, setErrors] = useState<string[]>([]);

  // ページを表示したときに1回だけ、ブラウザから API に、編集する記事を取りに行く
  useEffect(() => {
    fetch(`${process.env.NEXT_PUBLIC_API_URL}/posts/${id}`)
      .then(async (res) => {
        const data = await res.json();
        if (!res.ok) {
          setErrors([data.message]); // 例：Post 999 not found
          return;
        }
        setInitialValues({
          title: data.title,
          body: data.body,
          status: data.status,
        });
      })
      .catch((err) => setErrors([String(err)]));
  }, [id]);

  async function handleSubmit(values: PostFormValues) {
    const token = getAccessToken();
    // API に記事の更新を依頼する（PATCH /posts/:id）
    const res = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/posts/${id}`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        // ログインしていれば「Authorization: Bearer （トークン）」を付ける
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: JSON.stringify(values),
    });

    if (!res.ok) {
      const data = await res.json();
      setErrors(Array.isArray(data.message) ? data.message : [data.message]);
      return;
    }

    router.push("/"); // 作成できたら一覧に戻る
  }

  return (
    <main>
      <h1>記事を編集</h1>
      {/* 読み込みが終わるまではフォームを出さない（404 のときはエラーだけ出す） */}
      {initialValues ? (
        <PostForm
          initialValues={initialValues}
          submitLabel="保存"
          errors={errors}
          onSubmit={handleSubmit}
        />
      ) : (
        errors.map((message) => (
          <p key={message} className="error">
            {message}
          </p>
        ))
      )}
    </main>
  );
}
