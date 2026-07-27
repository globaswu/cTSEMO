function g = weldbeamconstr(x)
    P = 6000; % lb
    L = 14; % in
    % dmax = 0.25; % in
    E = 30E6; % psi
    G = 12E6; % psi
    tmax = 13600; % psi
    smax = 30000; % psi
    
    x1 = x(1); x2 = x(2); x3 = x(3); x4 = x(4);

    M = P*(L+.5*x2);
    R = sqrt(x2^2/4 + .25*(x1+x3)^2);
    J = sqrt(2)*x1*x2*(x2^2/12 + .25*(x2^2+(x1+x3)^2));
    taup = P/(sqrt(2)*x1*x2);
    taupp = M*R/J;

    g(:,1) = sqrt(taup^2 + taup*taupp*x2/R + taupp^2) - tmax;
    g(:,2) = 6*P*L/(x4*x3^2) - smax;
    g(:,3) = x1 - x4; % e3
    g(:,4) = P-64764.022*(1-0.0282346*x3)*x3*x4^3;
end
