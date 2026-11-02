"use client"; // このファイルはブラウザで動かす（付けないとサーバー側で動く）

import { useEffect, useState } from "react";
import Link from "next/link";

type Post = {
  id: number;
  title: string;
  status: "draft" | "published";
  imageUrl: string | null; // API が添える表示用の URL（4-2-7）
};

export default function HomePage() {
  const [posts, setPosts] = useState<Post[]>([]);
  const [error, setError] = useState("");

  // ページを表示したときに1回だけ、ブラウザから API に記事の一覧を取りに行く
  useEffect(() => {
    fetch(`${process.env.NEXT_PUBLIC_API_URL}/posts`)
      .then((res) => res.json())
      .then((data: Post[]) => setPosts(data))
      .catch((err) => setError(String(err)));
  }, []);

  return (
    <main>
      <h1>Mini Blog</h1>
      <p>
        <Link href="/posts/new">＋ 新しい記事</Link>
      </p>
      {error && <p className="error">{error}</p>}
      <ul>
        {posts.map((post) => (
          <li key={post.id}>
            [{post.status === "published" ? "公開" : "下書き"}] {post.title}{" "}
            <Link href={`/posts/${post.id}/edit`}>編集</Link><br/>
            {/* 画像があれば表示する。src は S3 の署名付き URL */}
            {post.imageUrl && (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={post.imageUrl} alt="" width={200} />
            )}
          </li>
        ))}
      </ul>
    </main>
  );
}