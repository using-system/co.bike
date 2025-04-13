import Head from 'next/head';
import dynamic from 'next/dynamic';
import Layout from '../components/Layout';

// Chargement dynamique de la carte pour éviter les problèmes liés au SSR
const App = dynamic(() => import('../components/App'), { ssr: false });

export default function Home() {
  return (
    <Layout>
      <Head>
        <title>Home | m8te.ai</title>
        <meta name="description" content="m8te.ai is a cutting-edge, secure chatbot solution that lets you query any type of data—whether it's databases, text files, or other sources—using natural language." />
      </Head>
      <div style={{ height: '70vh' }}>
        <App />
      </div>
    </Layout>
  );
}
