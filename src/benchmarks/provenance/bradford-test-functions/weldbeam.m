function f = weldbeam(x)
    P = 6000; % lb
    L = 14; % in
    E = 30e6; % psi 
    x1 = x(1); x2 = x(2); x3 = x(3); x4 = x(4);
    % x1 = h, x2 = l, x3 = t, x4 = b;
    
    f(:,1) = 1.10471*x1^2*x2+0.04811*x3*x4*(14.0+x3);
    f(:,2) = 4*P*L^3/(E*x4*x3^3);

end

