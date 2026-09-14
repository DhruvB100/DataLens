import { useState, useEffect} from "react";
import { API_BASE } from "./api";
import { BarChart, Bar, XAxis,YAxis, Tooltip, ResponsiveContainer } from "recharts";

export default function Dashboard() {
    const [stats,setStats] = useState([])

    useEffect(() => {
        fetch(`${API_BASE}/stats`)
            .then(res => res.json())
            .then(data => {
                const cleaned_data = data.map(row => {
                    return {
                        ...row,
                        num_events: Number(row.num_events),
                        avg_magnitude: Number(row.avg_magnitude)
                    };
                });

                setStats(cleaned_data);
            });
    }, []); 

    return (
        <div style={{padding: "20px"}}>
            <h3>Earthquakes per day</h3>

            <ResponsiveContainer width="100%" height={300}>
                <BarChart data={stats}>
                    <XAxis dataKey="dt" />
                    <YAxis />
                    <Tooltip />

                    <Bar dataKey="num_events" fill="#8884d8" />
        
                </BarChart>
            </ResponsiveContainer>
        </div>
    );
}